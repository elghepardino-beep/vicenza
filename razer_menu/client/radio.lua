-- ═══════════════════════════════════════════════
-- GESTIONE RADIO / ANIMAZIONI
-- ═══════════════════════════════════════════════
local radioSettings = {
    sound = 'click',
    animation = 'hand',
    speed = 1.0,
    prop = true
}

RegisterNUICallback('radio:save', function(data, cb)
    radioSettings.sound     = data.sound or radioSettings.sound
    radioSettings.animation = data.animation or radioSettings.animation
    radioSettings.speed     = tonumber(data.speed) or radioSettings.speed
    radioSettings.prop      = data.prop
    SetResourceKvp('razer_radio_settings', json.encode(radioSettings))
    cb('ok')
end)

RegisterNUICallback('radio:preview', function(data, cb)
    -- la preview suono avviene client-side via NUI <audio>
    cb('ok')
end)

CreateThread(function()
    local saved = GetResourceKvpString('razer_radio_settings')
    if saved then radioSettings = json.decode(saved) end
end)

exports('GetRadioSettings', function() return radioSettings end)