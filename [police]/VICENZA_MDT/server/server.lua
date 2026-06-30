local ACTIONS = {}

local function SafeJson(value)
    return json.encode(value or {})
end

local function ClampNumber(value, min, max, default)
    value = tonumber(value) or default
    if value < min then return min end
    if value > max then return max end
    return value
end

local function CleanString(value, maxLen)
    value = tostring(value or '')
    value = value:gsub('[%c]', '')
    if maxLen and #value > maxLen then
        value = value:sub(1, maxLen)
    end
    return value
end

local function GetIdentifier(xPlayer)
    if not xPlayer then return nil end
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()) or nil
end

local function GetOfficer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local job = xPlayer.job or {}
    local identifier = GetIdentifier(xPlayer)

    return {
        source = source,
        identifier = identifier,
        name = (xPlayer.getName and xPlayer.getName()) or GetPlayerName(source) or 'Sconosciuto',
        job = job.name or 'unknown',
        grade = tonumber(job.grade) or 0,
        gradeLabel = job.grade_label or '',
        group = (xPlayer.getGroup and xPlayer.getGroup()) or 'user'
    }
end

local function HasAccess(source)
    local officer = GetOfficer(source)
    if not officer then return false, nil end

    if Config.AdminGroups[officer.group] then
        return true, officer
    end

    local jobCfg = Config.AllowedJobs[officer.job]
    if not jobCfg then
        return false, officer
    end

    if officer.grade < (jobCfg.minGrade or 0) then
        return false, officer
    end

    return true, officer
end

local function HasGrade(source, requiredGrade)
    local ok, officer = HasAccess(source)
    if not ok then return false, officer end

    if Config.AdminGroups[officer.group] then
        return true, officer
    end

    return officer.grade >= requiredGrade, officer
end

local function CanApproveWarrants(officer)
    if not officer then return false end

    if Config.AdminGroups[officer.group] then
        return true
    end

    local required = Config.WarrantApprovalJobs[officer.job]
    return required ~= nil and officer.grade >= required
end

local function Audit(source, action, payload)
    local officer = GetOfficer(source)
    if not officer then return end

    MySQL.insert.await(
        'INSERT INTO vicenza_mdt_audit (officer_identifier, officer_name, action, payload) VALUES (?, ?, ?, ?)',
        {
            officer.identifier,
            officer.name,
            action,
            SafeJson(payload)
        }
    )
end

local function BroadcastRefresh(scope)
    TriggerClientEvent('vicenza_mdt:client:refresh', -1, scope)
end

local function GetDashboard()
    local activeWarrants = MySQL.scalar.await(
        "SELECT COUNT(*) FROM vicenza_mdt_warrants WHERE status IN ('active', 'pending')"
    ) or 0

    local activeBolos = MySQL.scalar.await(
        "SELECT COUNT(*) FROM vicenza_mdt_bolos WHERE status = 'active'"
    ) or 0

    local openIncidents = MySQL.scalar.await(
        "SELECT COUNT(*) FROM vicenza_mdt_incidents WHERE status IN ('open', 'investigating')"
    ) or 0

    local chargesCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM vicenza_mdt_charges WHERE active = 1'
    ) or 0

    local recentIncidents = MySQL.query.await(
        'SELECT id, type, title, status, priority, created_by_name, created_at FROM vicenza_mdt_incidents ORDER BY id DESC LIMIT 8'
    ) or {}

    local warrants = MySQL.query.await(
        "SELECT id, target_type, target_label, plate, title, status, expires_at, created_at FROM vicenza_mdt_warrants WHERE status IN ('active', 'pending') ORDER BY id DESC LIMIT 8"
    ) or {}

    local bolos = MySQL.query.await(
        "SELECT id, type, title, plate, person_label, priority, status, created_at FROM vicenza_mdt_bolos WHERE status = 'active' ORDER BY id DESC LIMIT 8"
    ) or {}

    local announcements = MySQL.query.await(
        'SELECT id, title, message, priority, created_by_name, created_at FROM vicenza_mdt_announcements ORDER BY id DESC LIMIT 5'
    ) or {}

    return {
        stats = {
            activeWarrants = activeWarrants,
            activeBolos = activeBolos,
            openIncidents = openIncidents,
            chargesCount = chargesCount
        },
        recentIncidents = recentIncidents,
        warrants = warrants,
        bolos = bolos,
        announcements = announcements
    }
end

local function SeedCharges()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM vicenza_mdt_charges') or 0
    if count > 0 then return end

    for _, charge in ipairs(Config.DefaultCharges) do
        MySQL.insert.await(
            'INSERT INTO vicenza_mdt_charges (code, category, title, description, fine, jail) VALUES (?, ?, ?, ?, ?, ?)',
            {
                charge.code,
                charge.category,
                charge.title,
                charge.description,
                charge.fine,
                charge.jail
            }
        )
    end

    print('[VICENZA_MDT] Codice penale iniziale importato.')
end

CreateThread(function()
    Wait(1500)
    local ok, err = pcall(SeedCharges)
    if not ok then
        print(('[VICENZA_MDT] Errore seed charges: %s'):format(err))
    end
end)

ESX.RegisterServerCallback('vicenza_mdt:server:canOpen', function(source, cb)
    local allowed, officer = HasAccess(source)

    if not allowed then
        cb({
            ok = false,
            message = Config.Notifications.noAccess
        })
        return
    end

    Audit(source, 'open_mdt', {})

    cb({
        ok = true,
        officer = officer,
        dashboard = GetDashboard(),
        config = {
            permissions = Config.Permissions
        }
    })
end)

ACTIONS.boot = function(source)
    local _, officer = HasAccess(source)

    return {
        ok = true,
        officer = officer,
        dashboard = GetDashboard()
    }
end

ACTIONS.searchCitizens = function(source, payload)
    local q = CleanString(payload.q, 80)
    local limit = ClampNumber(payload.limit, 1, 50, 20)

    if #q < 2 then
        return { ok = true, results = {} }
    end

    local term = '%' .. q .. '%'
    local phoneColumn = Config.UsersPhoneColumn

    local selectPhone = ', NULL AS phone'
    local phoneWhere = ''
    local params = { term, term }

    if phoneColumn and phoneColumn:match('^[%w_]+$') then
        selectPhone = (', %s AS phone'):format(phoneColumn)
        phoneWhere = (' OR %s LIKE ?'):format(phoneColumn)
        params[#params + 1] = term
    end

    local sql = ([[
        SELECT identifier, firstname, lastname, dateofbirth, sex, height %s
        FROM users
        WHERE identifier LIKE ?
           OR CONCAT(COALESCE(firstname, ''), ' ', COALESCE(lastname, '')) LIKE ?
           %s
        ORDER BY firstname ASC, lastname ASC
        LIMIT %d
    ]]):format(selectPhone, phoneWhere, limit)

    local rows = MySQL.query.await(sql, params) or {}

    Audit(source, 'search_citizens', { q = q })

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.getCitizen = function(source, payload)
    local identifier = CleanString(payload.identifier, 80)
    if identifier == '' then
        return { ok = false, message = 'Identifier mancante.' }
    end

    local citizen = MySQL.single.await(
        'SELECT identifier, firstname, lastname, dateofbirth, sex, height FROM users WHERE identifier = ? LIMIT 1',
        { identifier }
    )

    if not citizen then
        return { ok = false, message = 'Cittadino non trovato.' }
    end

    local profile = MySQL.single.await(
        'SELECT * FROM vicenza_mdt_profiles WHERE identifier = ? LIMIT 1',
        { identifier }
    ) or {}

    local vehicles = MySQL.query.await(
        'SELECT plate, vehicle, type, stored FROM owned_vehicles WHERE owner = ? ORDER BY plate ASC',
        { identifier }
    ) or {}

    local warrants = MySQL.query.await(
        "SELECT * FROM vicenza_mdt_warrants WHERE target_identifier = ? AND status IN ('pending', 'active') ORDER BY id DESC",
        { identifier }
    ) or {}

    local bolos = MySQL.query.await(
        "SELECT * FROM vicenza_mdt_bolos WHERE person_identifier = ? AND status = 'active' ORDER BY id DESC",
        { identifier }
    ) or {}

    local incidents = MySQL.query.await(
        'SELECT id, type, title, status, priority, created_by_name, created_at FROM vicenza_mdt_incidents WHERE involved LIKE ? ORDER BY id DESC LIMIT 30',
        { '%' .. identifier .. '%' }
    ) or {}

    local licenses = {}

    if Config.UseUserLicenses then
        local ok, result = pcall(function()
            return MySQL.query.await(
                'SELECT type FROM user_licenses WHERE owner = ? ORDER BY type ASC',
                { identifier }
            ) or {}
        end)

        if ok then
            licenses = result
        end
    end

    Audit(source, 'get_citizen', { identifier = identifier })

    return {
        ok = true,
        citizen = citizen,
        profile = profile,
        vehicles = vehicles,
        warrants = warrants,
        bolos = bolos,
        incidents = incidents,
        licenses = licenses
    }
end

ACTIONS.saveCitizenProfile = function(source, payload)
    local _, officer = HasAccess(source)

    local identifier = CleanString(payload.identifier, 80)
    local image = CleanString(payload.image, 1000)
    local notes = CleanString(payload.notes, 6000)
    local riskLevel = CleanString(payload.risk_level, 20)
    local tags = payload.tags or {}

    if identifier == '' then
        return { ok = false, message = 'Identifier mancante.' }
    end

    MySQL.update.await(
        [[
            INSERT INTO vicenza_mdt_profiles
                (identifier, image, notes, tags, risk_level, updated_by)
            VALUES
                (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                image = VALUES(image),
                notes = VALUES(notes),
                tags = VALUES(tags),
                risk_level = VALUES(risk_level),
                updated_by = VALUES(updated_by)
        ]],
        {
            identifier,
            image,
            notes,
            SafeJson(tags),
            riskLevel,
            officer.identifier
        }
    )

    Audit(source, 'save_citizen_profile', {
        identifier = identifier,
        risk_level = riskLevel
    })

    return {
        ok = true,
        message = Config.Notifications.saved
    }
end

ACTIONS.searchVehicles = function(source, payload)
    local q = CleanString(payload.q, 40)
    local limit = ClampNumber(payload.limit, 1, 50, 20)

    if #q < 2 then
        return { ok = true, results = {} }
    end

    local term = '%' .. q .. '%'

    local rows = MySQL.query.await(
        ('SELECT owner, plate, vehicle, type, stored FROM owned_vehicles WHERE plate LIKE ? OR vehicle LIKE ? ORDER BY plate ASC LIMIT %d'):format(limit),
        { term, term }
    ) or {}

    Audit(source, 'search_vehicles', { q = q })

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.getVehicle = function(source, payload)
    local plate = CleanString(payload.plate, 20)
    if plate == '' then
        return { ok = false, message = 'Targa mancante.' }
    end

    local vehicle = MySQL.single.await(
        'SELECT owner, plate, vehicle, type, stored FROM owned_vehicles WHERE plate = ? LIMIT 1',
        { plate }
    )

    if not vehicle then
        return { ok = false, message = 'Veicolo non trovato.' }
    end

    local warrants = MySQL.query.await(
        "SELECT * FROM vicenza_mdt_warrants WHERE plate = ? AND status IN ('pending', 'active') ORDER BY id DESC",
        { plate }
    ) or {}

    local bolos = MySQL.query.await(
        "SELECT * FROM vicenza_mdt_bolos WHERE plate = ? AND status = 'active' ORDER BY id DESC",
        { plate }
    ) or {}

    Audit(source, 'get_vehicle', { plate = plate })

    return {
        ok = true,
        vehicle = vehicle,
        warrants = warrants,
        bolos = bolos
    }
end

ACTIONS.listIncidents = function(source, payload)
    local limit = ClampNumber(payload.limit, 1, 100, 40)

    local rows = MySQL.query.await(
        ('SELECT id, type, title, status, priority, location, created_by_name, created_at, updated_at FROM vicenza_mdt_incidents ORDER BY id DESC LIMIT %d'):format(limit)
    ) or {}

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.getIncident = function(source, payload)
    local id = tonumber(payload.id)
    if not id then
        return { ok = false, message = 'ID incidente mancante.' }
    end

    local row = MySQL.single.await(
        'SELECT * FROM vicenza_mdt_incidents WHERE id = ? LIMIT 1',
        { id }
    )

    if not row then
        return { ok = false, message = 'Incidente non trovato.' }
    end

    Audit(source, 'get_incident', { id = id })

    return {
        ok = true,
        incident = row
    }
end

ACTIONS.createIncident = function(source, payload)
    local _, officer = HasAccess(source)

    local title = CleanString(payload.title, 255)
    if #title < 3 then
        return { ok = false, message = 'Titolo troppo corto.' }
    end

    local id = MySQL.insert.await(
        [[
            INSERT INTO vicenza_mdt_incidents
                (type, title, summary, status, priority, location, involved, evidence, charges, created_by, created_by_name)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]],
        {
            CleanString(payload.type or 'criminal', 40),
            title,
            CleanString(payload.summary, 10000),
            CleanString(payload.status or 'open', 40),
            CleanString(payload.priority or 'normal', 20),
            CleanString(payload.location, 255),
            SafeJson(payload.involved or {}),
            SafeJson(payload.evidence or {}),
            SafeJson(payload.charges or {}),
            officer.identifier,
            officer.name
        }
    )

    Audit(source, 'create_incident', {
        id = id,
        title = title
    })

    BroadcastRefresh('incidents')

    return {
        ok = true,
        id = id,
        message = 'Incidente creato.'
    }
end

ACTIONS.updateIncident = function(source, payload)
    local id = tonumber(payload.id)
    if not id then
        return { ok = false, message = 'ID incidente mancante.' }
    end

    local row = MySQL.single.await(
        'SELECT created_by FROM vicenza_mdt_incidents WHERE id = ? LIMIT 1',
        { id }
    )

    if not row then
        return { ok = false, message = 'Incidente non trovato.' }
    end

    local _, officer = HasAccess(source)

    MySQL.update.await(
        [[
            UPDATE vicenza_mdt_incidents
            SET type = ?, title = ?, summary = ?, status = ?, priority = ?, location = ?,
                involved = ?, evidence = ?, charges = ?
            WHERE id = ?
        ]],
        {
            CleanString(payload.type or 'criminal', 40),
            CleanString(payload.title, 255),
            CleanString(payload.summary, 10000),
            CleanString(payload.status or 'open', 40),
            CleanString(payload.priority or 'normal', 20),
            CleanString(payload.location, 255),
            SafeJson(payload.involved or {}),
            SafeJson(payload.evidence or {}),
            SafeJson(payload.charges or {}),
            id
        }
    )

    Audit(source, 'update_incident', {
        id = id,
        officer = officer.identifier
    })

    BroadcastRefresh('incidents')

    return {
        ok = true,
        message = Config.Notifications.saved
    }
end

ACTIONS.deleteIncident = function(source, payload)
    local allowed = HasGrade(source, Config.Permissions.deleteIncidents)
    if not allowed then
        return { ok = false, message = 'Permessi insufficienti.' }
    end

    local id = tonumber(payload.id)
    if not id then
        return { ok = false, message = 'ID mancante.' }
    end

    MySQL.update.await(
        'DELETE FROM vicenza_mdt_incidents WHERE id = ?',
        { id }
    )

    Audit(source, 'delete_incident', { id = id })
    BroadcastRefresh('incidents')

    return {
        ok = true,
        message = 'Incidente eliminato.'
    }
end

ACTIONS.listWarrants = function(source, payload)
    local status = CleanString(payload.status or 'active', 30)

    local rows = MySQL.query.await(
        'SELECT * FROM vicenza_mdt_warrants WHERE status = ? ORDER BY id DESC LIMIT 100',
        { status }
    ) or {}

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.createWarrant = function(source, payload)
    local _, officer = HasAccess(source)

    local title = CleanString(payload.title, 255)
    if #title < 3 then
        return { ok = false, message = 'Titolo mandato troppo corto.' }
    end

    local status = 'pending'

    if CanApproveWarrants(officer) then
        status = 'active'
    end

    local id = MySQL.insert.await(
        [[
            INSERT INTO vicenza_mdt_warrants
                (target_type, target_identifier, target_label, plate, title, reason, status, expires_at, created_by, created_by_name, approved_by, approved_at)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, IF(? IS NULL, NULL, NOW()))
        ]],
        {
            CleanString(payload.target_type or 'person', 20),
            CleanString(payload.target_identifier, 80),
            CleanString(payload.target_label, 160),
            CleanString(payload.plate, 20),
            title,
            CleanString(payload.reason, 6000),
            status,
            CleanString(payload.expires_at, 30),
            officer.identifier,
            officer.name,
            status == 'active' and officer.identifier or nil,
            status == 'active' and officer.identifier or nil
        }
    )

    Audit(source, 'create_warrant', {
        id = id,
        status = status
    })

    BroadcastRefresh('warrants')

    return {
        ok = true,
        id = id,
        status = status,
        message = status == 'active' and 'Mandato creato e attivo.' or 'Mandato inviato per approvazione.'
    }
end

ACTIONS.setWarrantStatus = function(source, payload)
    local _, officer = HasAccess(source)
    if not CanApproveWarrants(officer) then
        return { ok = false, message = 'Non puoi approvare/chiudere mandati.' }
    end

    local id = tonumber(payload.id)
    local status = CleanString(payload.status, 30)

    local allowedStatuses = {
        active = true,
        rejected = true,
        closed = true,
        expired = true
    }

    if not id or not allowedStatuses[status] then
        return { ok = false, message = 'Richiesta non valida.' }
    end

    MySQL.update.await(
        'UPDATE vicenza_mdt_warrants SET status = ?, approved_by = ?, approved_at = NOW() WHERE id = ?',
        {
            status,
            officer.identifier,
            id
        }
    )

    Audit(source, 'set_warrant_status', {
        id = id,
        status = status
    })

    BroadcastRefresh('warrants')

    return {
        ok = true,
        message = 'Stato mandato aggiornato.'
    }
end

ACTIONS.listBolos = function(source, payload)
    local status = CleanString(payload.status or 'active', 30)

    local rows = MySQL.query.await(
        'SELECT * FROM vicenza_mdt_bolos WHERE status = ? ORDER BY id DESC LIMIT 100',
        { status }
    ) or {}

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.createBolo = function(source, payload)
    local _, officer = HasAccess(source)

    local title = CleanString(payload.title, 255)
    if #title < 3 then
        return { ok = false, message = 'Titolo BOLO troppo corto.' }
    end

    local id = MySQL.insert.await(
        [[
            INSERT INTO vicenza_mdt_bolos
                (type, title, description, person_identifier, person_label, plate, image, priority, status, created_by, created_by_name)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)
        ]],
        {
            CleanString(payload.type or 'person', 30),
            title,
            CleanString(payload.description, 6000),
            CleanString(payload.person_identifier, 80),
            CleanString(payload.person_label, 160),
            CleanString(payload.plate, 20),
            CleanString(payload.image, 1000),
            CleanString(payload.priority or 'normal', 20),
            officer.identifier,
            officer.name
        }
    )

    Audit(source, 'create_bolo', {
        id = id,
        title = title
    })

    BroadcastRefresh('bolos')

    return {
        ok = true,
        id = id,
        message = 'BOLO creato.'
    }
end

ACTIONS.setBoloStatus = function(source, payload)
    local allowed = HasGrade(source, Config.Permissions.closeBolos)
    if not allowed then
        return { ok = false, message = 'Permessi insufficienti.' }
    end

    local id = tonumber(payload.id)
    local status = CleanString(payload.status, 30)

    if not id or (status ~= 'active' and status ~= 'closed') then
        return { ok = false, message = 'Richiesta non valida.' }
    end

    MySQL.update.await(
        'UPDATE vicenza_mdt_bolos SET status = ? WHERE id = ?',
        { status, id }
    )

    Audit(source, 'set_bolo_status', {
        id = id,
        status = status
    })

    BroadcastRefresh('bolos')

    return {
        ok = true,
        message = 'BOLO aggiornato.'
    }
end

ACTIONS.listCharges = function()
    local rows = MySQL.query.await(
        'SELECT * FROM vicenza_mdt_charges WHERE active = 1 ORDER BY category ASC, code ASC'
    ) or {}

    return {
        ok = true,
        results = rows
    }
end

ACTIONS.upsertCharge = function(source, payload)
    local allowed = HasGrade(source, Config.Permissions.manageCharges)
    if not allowed then
        return { ok = false, message = 'Permessi insufficienti.' }
    end

    local code = CleanString(payload.code, 40)
    local title = CleanString(payload.title, 255)

    if code == '' or title == '' then
        return { ok = false, message = 'Codice e titolo obbligatori.' }
    end

    MySQL.update.await(
        [[
            INSERT INTO vicenza_mdt_charges
                (code, category, title, description, fine, jail, active)
            VALUES
                (?, ?, ?, ?, ?, ?, 1)
            ON DUPLICATE KEY UPDATE
                category = VALUES(category),
                title = VALUES(title),
                description = VALUES(description),
                fine = VALUES(fine),
                jail = VALUES(jail),
                active = 1
        ]],
        {
            code,
            CleanString(payload.category or 'Generale', 80),
            title,
            CleanString(payload.description, 3000),
            ClampNumber(payload.fine, 0, 1000000, 0),
            ClampNumber(payload.jail, 0, 10000, 0)
        }
    )

    Audit(source, 'upsert_charge', { code = code })

    return {
        ok = true,
        message = Config.Notifications.saved
    }
end

ACTIONS.deleteCharge = function(source, payload)
    local allowed = HasGrade(source, Config.Permissions.manageCharges)
    if not allowed then
        return { ok = false, message = 'Permessi insufficienti.' }
    end

    local id = tonumber(payload.id)
    if not id then
        return { ok = false, message = 'ID mancante.' }
    end

    MySQL.update.await(
        'UPDATE vicenza_mdt_charges SET active = 0 WHERE id = ?',
        { id }
    )

    Audit(source, 'delete_charge', { id = id })

    return {
        ok = true,
        message = 'Reato disattivato.'
    }
end

ACTIONS.createAnnouncement = function(source, payload)
    local allowed, officer = HasGrade(source, Config.Permissions.announcements)
    if not allowed then
        return { ok = false, message = 'Permessi insufficienti.' }
    end

    local title = CleanString(payload.title, 255)
    local message = CleanString(payload.message, 6000)

    if title == '' or message == '' then
        return { ok = false, message = 'Titolo e messaggio obbligatori.' }
    end

    local id = MySQL.insert.await(
        'INSERT INTO vicenza_mdt_announcements (title, message, priority, created_by, created_by_name) VALUES (?, ?, ?, ?, ?)',
        {
            title,
            message,
            CleanString(payload.priority or 'normal', 20),
            officer.identifier,
            officer.name
        }
    )

    Audit(source, 'create_announcement', { id = id })
    BroadcastRefresh('announcements')

    return {
        ok = true,
        id = id,
        message = 'Annuncio pubblicato.'
    }
end

ACTIONS.applySentence = function(source, payload)
    local _, officer = HasAccess(source)

    local targetIdentifier = CleanString(payload.identifier, 80)
    local fine = ClampNumber(payload.fine, 0, 1000000, 0)
    local jail = ClampNumber(payload.jail, 0, 10000, 0)
    local charges = payload.charges or {}

    if targetIdentifier == '' then
        return { ok = false, message = 'Target mancante.' }
    end

    Audit(source, 'apply_sentence', {
        identifier = targetIdentifier,
        fine = fine,
        jail = jail,
        charges = charges
    })

    TriggerEvent('vicenza_mdt:server:sentenceIssued', {
        officer = officer,
        identifier = targetIdentifier,
        fine = fine,
        jail = jail,
        charges = charges
    })

    return {
        ok = true,
        message = 'Sentenza registrata. Collega il tuo jail/billing all’evento server sentenceIssued.'
    }
end

ESX.RegisterServerCallback('vicenza_mdt:server:action', function(source, cb, data)
    local allowed = HasAccess(source)

    if not allowed then
        cb({
            ok = false,
            message = Config.Notifications.noAccess
        })
        return
    end

    if not data or type(data) ~= 'table' then
        cb({
            ok = false,
            message = 'Payload non valido.'
        })
        return
    end

    local action = CleanString(data.action, 80)
    local payload = data.payload or {}

    if not ACTIONS[action] then
        cb({
            ok = false,
            message = 'Azione MDT non valida: ' .. action
        })
        return
    end

    local ok, result = pcall(ACTIONS[action], source, payload)

    if not ok then
        print(('[VICENZA_MDT] Errore action %s: %s'):format(action, result))

        cb({
            ok = false,
            message = Config.Notifications.error
        })
        return
    end

    cb(result or { ok = true })
end)

if Config.UseItem then
    ESX.RegisterUsableItem(Config.ItemName, function(source)
        local allowed = HasAccess(source)

        if not allowed then
            TriggerClientEvent('vicenza_mdt:client:notify', source, Config.Notifications.noAccess)
            return
        end

        TriggerClientEvent('chat:addMessage', source, {
            args = {
                'VICENZA MDT',
                'Usa /' .. Config.Command .. ' oppure il tasto ' .. Config.Keybind .. ' per aprire il tablet.'
            }
        })
    end)
end