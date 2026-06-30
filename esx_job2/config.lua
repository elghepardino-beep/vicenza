Config = {}

-- Gruppi autorizzati a usare /setjob2 (come /setjob ESX)
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true,
}

-- Pagamento automatico job2 (true = paga anche il job2, false = solo info)
Config.PayJob2 = true

-- Intervallo pagamento job2 (ms) — default 7 minuti come ESX
Config.PayInterval = 7 * 60 * 1000

-- Notifica al cambio job2
Config.NotifyOnChange = true