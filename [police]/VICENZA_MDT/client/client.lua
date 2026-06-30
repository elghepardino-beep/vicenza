local MDT_OPEN = false
local tabletObj = nil

local function Notify(msg)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg)
    else
        print(('[VICENZA_MDT] %s'):format(msg))
    end
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function StartTabletAnim()
    local ped = PlayerPedId()
    LoadAnimDict('amb@world_human_seat_wall_tablet@female@base')
    TaskPlayAnim(
        ped,
        'amb@world_human_seat_wall_tablet@female@base',
        'base',
        3.0,
        3.0,
        -1,
        49,
        0,
        false,
        false,
        false
    )

    local model = joaat('prop_cs_tablet')
    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(10)
    end

    tabletObj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        tabletObj,
        ped,
        GetPedBoneIndex(ped, 28422),
        0.0,
        -0.03,
        0.0,
        20.0,
        -90.0,
        0.0,
        true,
        true,
        false,
        true,
        1,
        true
    )
end

local function StopTabletAnim()
    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if tabletObj then
        DeleteEntity(tabletObj)
        tabletObj = nil
    end
end

local function CloseMDT()
    if not MDT_OPEN then return end

    MDT_OPEN = false
    SetNuiFocus(false, false)
    StopTabletAnim()

    SendNUIMessage({
        type = 'close'
    })

    Notify(Config.Notifications.closed)
end

local function OpenMDT()
    if MDT_OPEN then return end

    ESX.TriggerServerCallback('vicenza_mdt:server:canOpen', function(response)
        if not response or not response.ok then
            Notify(response and response.message or Config.Notifications.noAccess)
            return
        end

        MDT_OPEN = true
        SetNuiFocus(true, true)
        StartTabletAnim()

        SendNUIMessage({
            type = 'open',
            payload = response
        })

        Notify(Config.Notifications.opened)
    end)
end

RegisterCommand(Config.Command, function()
    OpenMDT()
end, false)

RegisterKeyMapping(Config.Command, 'Apri Vicenza MDT', 'keyboard', Config.Keybind)

RegisterNUICallback('close', function(_, cb)
    CloseMDT()
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    if not data or type(data) ~= 'table' then
        cb({ ok = false, message = 'Payload non valido.' })
        return
    end

    ESX.TriggerServerCallback('vicenza_mdt:server:action', function(response)
        cb(response or { ok = false, message = 'Nessuna risposta dal server.' })
    end, data)
end)

RegisterNetEvent('vicenza_mdt:client:notify', function(message)
    Notify(message)
end)

RegisterNetEvent('vicenza_mdt:client:refresh', function(scope)
    if MDT_OPEN then
        SendNUIMessage({
            type = 'refresh',
            scope = scope or 'all'
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if MDT_OPEN then
        SetNuiFocus(false, false)
        StopTabletAnim()
    end
end)

CreateThread(function()
    while true do
        if MDT_OPEN then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)

            if IsControlJustPressed(0, 322) then
                CloseMDT()
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)