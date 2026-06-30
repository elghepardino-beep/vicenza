ESX = exports['es_extended']:getSharedObject()

local isMenuOpen = false
local PlayerData = {}

-- ═══════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('esx:setJob2', function(job2)
    PlayerData.job2 = job2
end)

-- ═══════════════════════════════════════════════
-- APERTURA MENU
-- ═══════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.OpenKey) and not isMenuOpen then
            OpenMenu()
        end
    end
end)

function OpenMenu()
    if isMenuOpen then return end
    ESX.TriggerServerCallback('razer_menu:getPlayerData', function(data)
        isMenuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action     = 'open',
            theme      = Config.Theme,
            categories = Config.Categories,
            data       = data,
            radio      = Config.Radio,
            fps        = Config.FPS,
            adult      = Config.AdultAnims,
            serverName = Config.ServerName
        })
    end)
end

function CloseMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ═══════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════
RegisterNUICallback('close', function(_, cb)
    CloseMenu(); cb('ok')
end)

RegisterNUICallback('refreshData', function(_, cb)
    ESX.TriggerServerCallback('razer_menu:getPlayerData', function(data)
        cb(data)
    end)
end)

-- ── FATTURE: ponte verso razer_billing ──────────
RegisterNUICallback('openBilling', function(_, cb)
    CloseMenu()
    exports[Config.BillingResource]:OpenBillingUI()
    cb('ok')
end)

RegisterNUICallback('getBills', function(_, cb)
    ESX.TriggerServerCallback('razer_billing:getBills', function(bills)
        cb(bills or {})
    end)
end)

RegisterNUICallback('payBill', function(data, cb)
    TriggerServerEvent('razer_billing:payBill', data.id)
    cb('ok')
end)

-- ── FPS BOOSTER ─────────────────────────────────
local currentFPSPreset = 'off'
RegisterNUICallback('setFPS', function(data, cb)
    currentFPSPreset = data.preset
    ApplyFPSPreset(data.preset)
    cb('ok')
end)

function ApplyFPSPreset(presetId)
    local preset = nil
    for _, p in ipairs(Config.FPS.presets) do
        if p.id == presetId then preset = p break end
    end
    if not preset then return end
    SetTimecycleModifier('default')
    if presetId ~= 'off' then
        ClearTimecycleModifier()
        SetArtificialLightsState(presetId == 'high')
    end
    -- riduzione distanza di rendering
    SetFarDrawVehicles(presetId ~= 'high')
end

-- ── CASA ────────────────────────────────────────
RegisterNUICallback('houseAction', function(data, cb)
    TriggerEvent('razer_menu:houseAction', data.action)
    cb('ok')
end)

-- ── ANIMAZIONI +18 ──────────────────────────────
RegisterNUICallback('playAdultAnim', function(data, cb)
    local anim = nil
    for _, a in ipairs(Config.AdultAnims.list) do
        if a.id == data.id then anim = a break end
    end
    if anim then
        ESX.Streaming.RequestAnimDict(anim.dict, function()
            TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, 1.0, -1, 1, 0, false, false, false)
        end)
    end
    cb('ok')
end)