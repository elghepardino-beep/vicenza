ESX = exports['es_extended']:getSharedObject()

-- ═══════════════════════════════════════════════
-- CREA TABELLA AL PRIMO AVVIO
-- ═══════════════════════════════════════════════
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS razer_billing (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL,
            sender VARCHAR(60),
            target_society VARCHAR(60),
            label VARCHAR(255) NOT NULL,
            amount INT NOT NULL,
            category VARCHAR(40) DEFAULT 'other',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            paid TINYINT(1) DEFAULT 0,
            INDEX idx_identifier (identifier)
        )
    ]])
end)

-- ═══════════════════════════════════════════════
-- OTTIENI FATTURE
-- ═══════════════════════════════════════════════
ESX.RegisterServerCallback('razer_billing:getBills', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    local result = MySQL.query.await(
        'SELECT * FROM razer_billing WHERE identifier = ? AND paid = 0 ORDER BY created_at DESC',
        { xPlayer.identifier }
    )
    cb(result or {})
end)

-- ═══════════════════════════════════════════════
-- CREA FATTURA (chiamabile da altre risorse)
-- ═══════════════════════════════════════════════
RegisterNetEvent('razer_billing:createBill', function(targetIdentifier, society, label, amount)
    local senderIdentifier = nil
    if source and source > 0 then
        local x = ESX.GetPlayerFromId(source)
        if x then senderIdentifier = x.identifier end
    end
    local category = BillingConfig.SocietyMap[society] or 'other'
    MySQL.insert('INSERT INTO razer_billing (identifier, sender, target_society, label, amount, category) VALUES (?,?,?,?,?,?)',
        { targetIdentifier, senderIdentifier, society, label, amount, category })

    -- notifica online
    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    if xTarget then
        TriggerClientEvent('razer_billing:notify', xTarget.source, '📩 Hai ricevuto una nuova fattura: $' .. amount)
    end
end)

-- compatibilità con esx_billing
RegisterNetEvent('esx_billing:sendBill', function(playerId, society, label, amount)
    local xTarget = ESX.GetPlayerFromId(playerId)
    if not xTarget then return end
    TriggerEvent('razer_billing:createBill', xTarget.identifier, society, label, amount)
end)

-- ═══════════════════════════════════════════════
-- PAGA SINGOLA FATTURA
-- ═══════════════════════════════════════════════
RegisterNetEvent('razer_billing:payBill', function(billId, method)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local bill = MySQL.single.await('SELECT * FROM razer_billing WHERE id = ? AND identifier = ? AND paid = 0',
        { billId, xPlayer.identifier })
    if not bill then return end

    method = method or 'bank'
    if method == 'cash' then
        if xPlayer.getMoney() < bill.amount then
            return TriggerClientEvent('razer_billing:notify', source, '❌ Contanti insufficienti')
        end
        xPlayer.removeMoney(bill.amount)
    else
        if xPlayer.getAccount('bank').money < bill.amount then
            return TriggerClientEvent('razer_billing:notify', source, '❌ Saldo bancario insufficiente')
        end
        xPlayer.removeAccountMoney('bank', bill.amount)
    end

    -- Accredito società
    if bill.target_society and bill.target_society:find('society_') then
        TriggerEvent('esx_addonaccount:getSharedAccount', bill.target_society, function(account)
            if account then account.addMoney(bill.amount) end
        end)
    end

    MySQL.update('UPDATE razer_billing SET paid = 1 WHERE id = ?', { billId })
    TriggerClientEvent('razer_billing:notify', source, '✅ Fattura pagata: $' .. bill.amount)
end)

-- ═══════════════════════════════════════════════
-- PAGA TUTTE
-- ═══════════════════════════════════════════════
RegisterNetEvent('razer_billing:payAll', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local bills = MySQL.query.await('SELECT * FROM razer_billing WHERE identifier = ? AND paid = 0',
        { xPlayer.identifier })
    local total = 0
    for _, b in ipairs(bills) do total = total + b.amount end

    if xPlayer.getAccount('bank').money < total then
        return TriggerClientEvent('razer_billing:notify', source, '❌ Saldo insufficiente: serve $' .. total)
    end

    xPlayer.removeAccountMoney('bank', total)
    for _, b in ipairs(bills) do
        if b.target_society and b.target_society:find('society_') then
            TriggerEvent('esx_addonaccount:getSharedAccount', b.target_society, function(account)
                if account then account.addMoney(b.amount) end
            end)
        end
    end
    MySQL.update('UPDATE razer_billing SET paid = 1 WHERE identifier = ? AND paid = 0', { xPlayer.identifier })
    TriggerClientEvent('razer_billing:notify', source, '✅ Tutte le fatture pagate: $' .. total)
end)

-- ═══════════════════════════════════════════════
-- COMANDO ADMIN: aggiungi fattura test
-- /addbill [id] [importo] [descrizione]
-- ═══════════════════════════════════════════════
ESX.RegisterCommand('addbill', 'admin', function(xPlayer, args)
    local xTarget = ESX.GetPlayerFromId(args.target)
    if not xTarget then return end
    MySQL.insert('INSERT INTO razer_billing (identifier, label, amount, category) VALUES (?,?,?,?)',
        { xTarget.identifier, args.label, args.amount, 'other' })
    TriggerClientEvent('razer_billing:notify', args.target, '📩 Nuova fattura: $' .. args.amount)
end, false, {
    help = 'Aggiungi fattura test',
    arguments = {
        { name = 'target', help = 'ID giocatore', type = 'player' },
        { name = 'amount', help = 'Importo',      type = 'number' },
        { name = 'label',  help = 'Descrizione',  type = 'string' }
    }
})