BillingConfig = {}

BillingConfig.OpenCommand = 'fatture'         -- /fatture per aprire manualmente
BillingConfig.AutoPayDays = 7                 -- giorni prima auto-pagamento da banca
BillingConfig.SocietyAccountPrefix = 'society_'

BillingConfig.Theme = {
    primary    = '#8B5CF6',
    background = '#0F0F14',
    surface    = '#1A1A24',
    border     = '#2A2A38'
}

-- Categorie fatture (per filtri UI)
BillingConfig.Categories = {
    { id = 'all',     label = 'Tutte' },
    { id = 'gov',     label = 'Governo' },
    { id = 'police',  label = 'Polizia (Multe)' },
    { id = 'hospital',label = 'Ospedale' },
    { id = 'mechanic',label = 'Meccanico' },
    { id = 'shop',    label = 'Negozi' },
    { id = 'other',   label = 'Altro' }
}

-- Mappatura società → categoria
BillingConfig.SocietyMap = {
    ['society_police']   = 'police',
    ['society_ambulance']= 'hospital',
    ['society_mechanic'] = 'mechanic',
    ['government']       = 'gov'
}