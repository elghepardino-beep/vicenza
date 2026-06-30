Config = {}

Config.ResourceName = 'VICENZA_MDT'
Config.Command = 'mdt'
Config.Keybind = 'F7'
Config.UseItem = true
Config.ItemName = 'police_tablet'

Config.Locale = 'it'

Config.AllowedJobs = {
    police = {
        label = 'Polizia',
        minGrade = 0
    },
    sheriff = {
        label = 'Sceriffo',
        minGrade = 0
    }
}

Config.AdminGroups = {
    admin = true,
    superadmin = true
}

Config.WarrantApprovalJobs = {
    police = 4,
    sheriff = 4,
    doj = 0,
    judge = 0
}

Config.UsersPhoneColumn = false
-- Esempio se hai un telefono con colonna su users:
-- Config.UsersPhoneColumn = 'phone_number'

Config.UseUserLicenses = true

Config.Permissions = {
    manageCharges = 4,
    deleteIncidents = 4,
    approveWarrants = 4,
    closeBolos = 2,
    announcements = 3
}

Config.DefaultCharges = {
    {
        code = 'CP-001',
        category = 'Ordine Pubblico',
        title = 'Disturbo della quiete pubblica',
        description = 'Comportamento che arreca disturbo in luogo pubblico.',
        fine = 750,
        jail = 0
    },
    {
        code = 'CP-010',
        category = 'Codice Stradale',
        title = 'Guida pericolosa',
        description = 'Condotta di guida che mette a rischio persone o beni.',
        fine = 1500,
        jail = 0
    },
    {
        code = 'CP-020',
        category = 'Reati contro la persona',
        title = 'Aggressione',
        description = 'Uso della forza contro un altro individuo.',
        fine = 3500,
        jail = 10
    },
    {
        code = 'CP-030',
        category = 'Armi',
        title = 'Possesso illegale di arma',
        description = 'Possesso o trasporto di arma senza autorizzazione.',
        fine = 7000,
        jail = 20
    },
    {
        code = 'CP-040',
        category = 'Fuga',
        title = 'Fuga dalle forze dell’ordine',
        description = 'Elusione intenzionale di un controllo o inseguimento.',
        fine = 5000,
        jail = 15
    }
}

Config.Notifications = {
    noAccess = 'Non hai accesso al MDT.',
    opened = 'MDT aperto.',
    closed = 'MDT chiuso.',
    saved = 'Salvato correttamente.',
    error = 'Errore durante l’operazione.'
}