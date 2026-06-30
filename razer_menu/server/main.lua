ESX = exports['es_extended']:getSharedObject()

-- ═══════════════════════════════════════════════
-- CALLBACK: dati giocatore per menu
-- ═══════════════════════════════════════════════
ESX.RegisterServerCallback('razer_menu:getPlayerData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    local cash = xPlayer.getMoney()
    local bank = xPlayer.getAccount('bank').money

    -- Job 2 (sistema doppio lavoro)
    local job2 = { name = 'unemployed', label = 'Unemployed', grade_label = '' }
    if Config.DoubleJob then
        local result = MySQL.single.await('SELECT job2, job2_grade FROM users WHERE identifier = ?', { xPlayer.identifier })
        if result and result.job2 then
            local jobData = MySQL.single.await('SELECT label FROM jobs WHERE name = ?', { result.job2 })
            local gradeData = MySQL.single.await('SELECT label FROM job_grades WHERE job_name = ? AND grade = ?', { result.job2, result.job2_grade or 0 })
            job2 = {
                name = result.job2,
                label = jobData and jobData.label or 'Unemployed',
                grade_label = gradeData and gradeData.label or ''
            }
        end
    end

    -- Casa popolare (controllo proprietà)
    local hasHouse = false
    local houseResult = MySQL.scalar.await('SELECT COUNT(*) FROM owned_properties WHERE owner = ?', { xPlayer.identifier })
    hasHouse = (houseResult or 0) > 0

    cb({
        id = source,
        firstname = xPlayer.get('firstName') or 'Sconosciuto',
        lastname  = xPlayer.get('lastName') or '',
        identifier = xPlayer.identifier,
        cash = cash,
        bank = bank,
        job = {
            name = xPlayer.job.name,
            label = xPlayer.job.label,
            grade_label = xPlayer.job.grade_label
        },
        job2 = job2,
        hasHouse = hasHouse,
        group = xPlayer.getGroup(),
        isAdmin = IsAdmin(xPlayer.getGroup())
    })
end)

function IsAdmin(group)
    for _, g in ipairs(Config.AdminGroups) do
        if g == group then return true end
    end
    return false
end

exports('IsAdminGroup', IsAdmin)