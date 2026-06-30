ESX = exports['es_extended']:getSharedObject()
local isOpen = false

-- Comando manuale
RegisterCommand(BillingConfig.OpenCommand, function()
    OpenBillingUI()
end)

function OpenBillingUI()
    if isOpen then return end
    ESX.TriggerServerCallback('razer_billing:getBills', function(bills)
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            theme = BillingConfig.Theme,
            categories = BillingConfig.Categories,
            bills = bills or {}
        })
    end)
end

exports('OpenBillingUI', OpenBillingUI)

RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('pay', function(data, cb)
    TriggerServerEvent('razer_billing:payBill', data.id, data.method)
    cb('ok')
end)

RegisterNUICallback('payAll', function(_, cb)
    TriggerServerEvent('razer_billing:payAll')
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    ESX.TriggerServerCallback('razer_billing:getBills', function(bills)
        cb(bills or {})
    end)
end)

RegisterNetEvent('razer_billing:notify', function(msg, type)
    ESX.ShowNotification(msg)
end)