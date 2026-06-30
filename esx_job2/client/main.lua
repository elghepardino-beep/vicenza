local ESX = exports['es_extended']:getSharedObject()

PlayerData = {}
PlayerData.job2 = nil

-- Ricevi il job2 dal server
RegisterNetEvent('esx_job2:setJob2', function(job2)
    PlayerData.job2 = job2
    -- Trigger di evento client per altre risorse
    TriggerEvent('esx_job2:setJob2', job2)
end)

-- Al login richiedi il job2 corrente
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.TriggerServerCallback('esx_job2:getJob2', function(job2)
        PlayerData.job2 = job2
    end)
end)

-- Export per ottenere il job2 lato client
exports('GetJob2', function()
    return PlayerData.job2
end)

-- Comando di debug: /myjob2
RegisterCommand('myjob2', function()
    if PlayerData.job2 then
        ESX.ShowNotification(('Job2: %s | Grado: %s'):format(
            PlayerData.job2.label,
            PlayerData.job2.grade_label
        ))
    else
        ESX.ShowNotification('~r~Nessun Job2')
    end
end, false)