-- ═══════════════════════════════════════════════
-- PANNELLO AMMIN - RICERCA UTENTE
-- ═══════════════════════════════════════════════
ESX.RegisterServerCallback('razer_menu:adminSearchPlayer', function(source, cb, targetId)
    local xAdmin = ESX.GetPlayerFromId(source)
    if not xAdmin or not exports['razer_menu']:IsAdminGroup(xAdmin.getGroup()) then
        return cb({ error = 'Permessi insufficienti' })
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return cb({ error = 'Giocatore offline o ID errato' }) end

    -- Estrai identificatori
    local discord, license, steam = nil, nil, nil
    for _, id in ipairs(GetPlayerIdentifiers(targetId)) do
        if id:match('discord:') then discord = id:gsub('discord:', '') end
        if id:match('license:') then license = id end
        if id:match('steam:')   then steam = id end
    end

    -- Dati job 2
    local job2 = MySQL.single.await('SELECT job2 FROM users WHERE identifier = ?', { xTarget.identifier })

    cb({
        id = targetId,
        firstname = xTarget.get('firstName') or 'N/D',
        lastname  = xTarget.get('lastName') or '',
        identifier = xTarget.identifier,
        license = license or 'N/D',
        discord = discord or 'N/D',
        steam = steam or 'N/D',
        group = xTarget.getGroup(),
        job = xTarget.job.label,
        job2 = (job2 and job2.job2) or 'unemployed',
        bank = xTarget.getAccount('bank').money,
        cash = xTarget.getMoney()
    })
end)