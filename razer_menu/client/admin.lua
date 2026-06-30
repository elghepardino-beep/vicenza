-- ═══════════════════════════════════════════════
-- PANNELLO AMMINISTRAZIONE
-- ═══════════════════════════════════════════════

RegisterNUICallback('admin:searchPlayer', function(data, cb)
    ESX.TriggerServerCallback('razer_menu:adminSearchPlayer', function(result)
        cb(result or { error = 'Giocatore non trovato' })
    end, tonumber(data.id))
end)

RegisterNUICallback('admin:repairVehicle', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetVehicleFixed(veh)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleEngineHealth(veh, 1000.0)
        ESX.ShowNotification('🔧 Veicolo riparato')
    else
        ESX.ShowNotification('❌ Non sei in un veicolo')
    end
    cb('ok')
end)

RegisterNUICallback('admin:openTuning', function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        TriggerEvent('esx_vehicleshop:openTuningMenu', veh)
    end
    cb('ok')
end)