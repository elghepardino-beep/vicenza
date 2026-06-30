local ESX = exports['es_extended']:getSharedObject()

local Jobs2 = {}      -- cache jobs2
local PlayerJob2 = {} -- cache job2 per player [identifier] = {name, grade, ...}

-----------------------------------------------------------
-- Carica jobs2 dal DB all'avvio
-----------------------------------------------------------
local function LoadJobs2()
    Jobs2 = {}
    local jobs = MySQL.query.await('SELECT * FROM jobs2', {})
    for _, job in ipairs(jobs) do
        Jobs2[job.name] = {
            name = job.name,
            label = job.label,
            whitelisted = job.whitelisted == 1,
            grades = {}
        }
    end

    local grades = MySQL.query.await('SELECT * FROM job2_grades', {})
    for _, g in ipairs(grades) do
        if Jobs2[g.job_name] then
            Jobs2[g.job_name].grades[tostring(g.grade)] = {
                job_name   = g.job_name,
                grade      = g.grade,
                name       = g.name,
                label      = g.label,
                salary     = g.salary,
                skin_male  = g.skin_male or '{}',
                skin_female= g.skin_female or '{}',
            }
        end
    end

    print(('[esx_job2] Caricati %s job2 dal database'):format(#jobs))
end

-----------------------------------------------------------
-- Util: ottieni dati job2 di un xPlayer
-----------------------------------------------------------
local function GetPlayerJob2(xPlayer)
    return PlayerJob2[xPlayer.identifier]
end

local function BuildJob2Object(jobName, grade)
    if not Jobs2[jobName] then
        jobName = 'unemployed'
        grade = 0
    end
    local job = Jobs2[jobName]
    local gradeData = job.grades[tostring(grade)] or job.grades['0']
    if not gradeData then return nil end

    return {
        id          = 0,
        name        = job.name,
        label       = job.label,
        grade       = gradeData.grade,
        grade_name  = gradeData.name,
        grade_label = gradeData.label,
        grade_salary= gradeData.salary,
        skin_male   = gradeData.skin_male,
        skin_female = gradeData.skin_female,
    }
end

-----------------------------------------------------------
-- Carica il job2 di un player al login
-----------------------------------------------------------
local function LoadPlayerJob2(xPlayer)
    local result = MySQL.single.await(
        'SELECT job2, job2_grade FROM users WHERE identifier = ?',
        { xPlayer.identifier }
    )

    local jobName = (result and result.job2) or 'unemployed'
    local grade   = (result and result.job2_grade) or 0

    if not Jobs2[jobName] then
        jobName = 'unemployed'
        grade = 0
    end

    PlayerJob2[xPlayer.identifier] = BuildJob2Object(jobName, grade)

    -- Sincronizza con il client
    TriggerClientEvent('esx_job2:setJob2', xPlayer.source, PlayerJob2[xPlayer.identifier])
end

-----------------------------------------------------------
-- Imposta job2 al player (equivalente a xPlayer.setJob)
-----------------------------------------------------------
local function SetPlayerJob2(source, jobName, grade)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'Player non trovato' end

    if not Jobs2[jobName] then
        return false, ('Job2 "%s" non esistente'):format(jobName)
    end

    if not Jobs2[jobName].grades[tostring(grade)] then
        return false, ('Grado %s inesistente per job2 "%s"'):format(grade, jobName)
    end

    local lastJob2 = PlayerJob2[xPlayer.identifier]
    PlayerJob2[xPlayer.identifier] = BuildJob2Object(jobName, grade)

    -- Aggiorna DB
    MySQL.update('UPDATE users SET job2 = ?, job2_grade = ? WHERE identifier = ?', {
        jobName, grade, xPlayer.identifier
    })

    -- Sincronizza client
    TriggerClientEvent('esx_job2:setJob2', xPlayer.source, PlayerJob2[xPlayer.identifier])

    -- Evento per altre risorse
    TriggerEvent('esx_job2:setJob2', xPlayer.source, PlayerJob2[xPlayer.identifier], lastJob2)

    if Config.NotifyOnChange then
        TriggerClientEvent('esx:showNotification', xPlayer.source,
            ('~g~Nuovo job2:~s~ %s (%s)'):format(
                Jobs2[jobName].label,
                Jobs2[jobName].grades[tostring(grade)].label
            )
        )
    end

    return true
end

-----------------------------------------------------------
-- Export: per usarlo da altre risorse, come xPlayer.setJob
-----------------------------------------------------------
exports('SetPlayerJob2', SetPlayerJob2)
exports('GetPlayerJob2', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    return PlayerJob2[xPlayer.identifier]
end)
exports('GetJobs2', function() return Jobs2 end)

-----------------------------------------------------------
-- Aggancia il job2 a xPlayer come metodo: xPlayer.setJob2 / getJob2
-----------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    LoadPlayerJob2(xPlayer)

    -- Inietta metodi sul xPlayer
    xPlayer.setJob2 = function(jobName, grade)
        return SetPlayerJob2(playerId, jobName, grade)
    end

    xPlayer.getJob2 = function()
        return PlayerJob2[xPlayer.identifier]
    end
end)

AddEventHandler('esx:playerDropped', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        PlayerJob2[xPlayer.identifier] = nil
    end
end)

-----------------------------------------------------------
-- COMANDO /setjob2 (identico a /setjob di ESX)
-- Uso: /setjob2 <id> <jobName> <grade>
-----------------------------------------------------------
ESX.RegisterCommand('setjob2', 'admin', function(xPlayer, args, showError)
    local target = args.playerId
    local jobName = args.job
    local grade = args.grade

    if not target then
        return showError('Player ID non valido')
    end

    local ok, err = SetPlayerJob2(target.source, jobName, grade)
    if not ok then
        showError(err)
    else
        if xPlayer then
            xPlayer.showNotification(('~g~Job2 impostato:~s~ %s (%s) a ID %s'):format(jobName, grade, target.source))
        else
            print(('[esx_job2] Job2 %s grado %s impostato a ID %s'):format(jobName, grade, target.source))
        end
    end
end, true, {
    help = 'Imposta il job2 di un giocatore (uguale a /setjob)',
    validate = true,
    arguments = {
        { name = 'playerId', help = 'ID giocatore', type = 'player' },
        { name = 'job',      help = 'Nome del job2', type = 'string' },
        { name = 'grade',    help = 'Grado del job2', type = 'number' },
    }
})

-----------------------------------------------------------
-- Pagamento periodico del job2 (opzionale)
-----------------------------------------------------------
if Config.PayJob2 then
    CreateThread(function()
        while true do
            Wait(Config.PayInterval)
            for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
                local job2 = PlayerJob2[xPlayer.identifier]
                if job2 and job2.grade_salary and job2.grade_salary > 0 then
                    xPlayer.addAccountMoney('bank', job2.grade_salary)
                    TriggerClientEvent('esx:showNotification', xPlayer.source,
                        ('~g~Stipendio Job2:~s~ $%s'):format(job2.grade_salary)
                    )
                end
            end
        end
    end)
end

-----------------------------------------------------------
-- Callback per il client
-----------------------------------------------------------
ESX.RegisterServerCallback('esx_job2:getJob2', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    cb(PlayerJob2[xPlayer.identifier])
end)

-----------------------------------------------------------
-- Avvio
-----------------------------------------------------------
MySQL.ready(function()
    LoadJobs2()
end)