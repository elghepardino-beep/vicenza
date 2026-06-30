Config = {}

-- ═══════════════════════════════════════════════
-- IMPOSTAZIONI GENERALI
-- ═══════════════════════════════════════════════
Config.OpenKey = 166               -- F5 (vedi https://docs.fivem.net/docs/game-references/controls/)
Config.Locale = 'it'
Config.ServerName = 'RAZER ROLEPLAY'
Config.UpdateInterval = 5000       -- ms aggiornamento dati in tempo reale

-- ═══════════════════════════════════════════════
-- TEMA UI (totalmente personalizzabile)
-- ═══════════════════════════════════════════════
Config.Theme = {
    primary    = '#8B5CF6',        -- Viola principale
    secondary  = '#A78BFA',        -- Viola chiaro
    accent     = '#7C3AED',        -- Viola scuro accento
    background = '#0F0F14',        -- Sfondo scuro
    surface    = '#1A1A24',        -- Card / superfici
    border     = '#2A2A38',        -- Bordi
    text       = '#FFFFFF',
    textMuted  = '#9CA3AF',
    success    = '#10B981',
    danger     = '#EF4444',
    warning    = '#F59E0B'
}

-- ═══════════════════════════════════════════════
-- CATEGORIE MENU PRINCIPALE
-- (puoi abilitare/disabilitare singole voci)
-- ═══════════════════════════════════════════════
Config.Categories = {
    { id = 'info',       label = 'Informazioni Personali', icon = 'user',        enabled = true },
    { id = 'billing',    label = 'Gestione Fatture',       icon = 'receipt',     enabled = true },
    { id = 'radio',      label = 'Animazioni Radio',       icon = 'radio',       enabled = true },
    { id = 'fps',        label = 'Gestione FPS',           icon = 'gauge',       enabled = true },
    { id = 'adult',      label = 'Animazioni +18',         icon = 'flame',       enabled = true },
    { id = 'house',      label = 'Gestione Casa',          icon = 'home',        enabled = true },
    { id = 'admin',      label = 'Amministrazione',        icon = 'shield',      enabled = true, adminOnly = true }
}

-- ═══════════════════════════════════════════════
-- GRUPPI ADMIN (chi vede la voce Amministrazione)
-- ═══════════════════════════════════════════════
Config.AdminGroups = { 'admin', 'superadmin', 'mod' }

-- ═══════════════════════════════════════════════
-- LAVORI / DOPPIO LAVORO
-- ═══════════════════════════════════════════════
Config.DoubleJob = true            -- abilita Job 1 + Job 2
Config.SecondJobColumn = 'job2'    -- nome colonna nel DB users

-- ═══════════════════════════════════════════════
-- IMPOSTAZIONI FPS BOOSTER
-- ═══════════════════════════════════════════════
Config.FPS = {
    presets = {
        { id = 'off',     label = 'Disattivato',    distance = 1000 },
        { id = 'low',     label = 'Basso',          distance = 600 },
        { id = 'medium',  label = 'Medio',          distance = 400 },
        { id = 'high',    label = 'Alto (Max FPS)', distance = 200 }
    }
}

-- ═══════════════════════════════════════════════
-- RADIO - PACCHETTI SUONI
-- ═══════════════════════════════════════════════
Config.Radio = {
    sounds = {
        { id = 'police',       label = 'Police Sounds',     file = 'police.ogg' },
        { id = 'fbi',          label = 'FBI',               file = 'fbi.ogg' },
        { id = 'bubble',       label = 'Bubble Explosion',  file = 'bubble.ogg' },
        { id = 'notification', label = 'Notification',      file = 'notification.ogg' },
        { id = 'click',        label = 'Click',             file = 'click.ogg' },
        { id = 'bell',         label = 'Bell',              file = 'bell.ogg' },
        { id = 'call',         label = 'Call',              file = 'call.ogg' },
        { id = 'beep',         label = 'Beep',              file = 'beep.ogg' }
    },
    animations = {
        { id = 'none',   label = 'Nessuna' },
        { id = 'hand',   label = 'Mano all\'orecchio', dict = 'random@arrests', anim = 'generic_radio_chatter' },
        { id = 'walkie', label = 'Walkie-Talkie',      dict = 'cellphone@',     anim = 'cellphone_text_read_base' },
        { id = 'phone',  label = 'Telefono',           dict = 'cellphone@',     anim = 'cellphone_call_listen_base' }
    },
    defaultSpeed = 1.0,
    showProp = true
}

-- ═══════════════════════════════════════════════
-- ANIMAZIONI +18 (regolamentate)
-- ═══════════════════════════════════════════════
Config.AdultAnims = {
    requireConsent = true,
    distance = 2.0,
    list = {
        { id = 'hug',  label = 'Abbraccio',  dict = 'mp_ped_interaction', anim = 'hugs_guy_a' },
        { id = 'kiss', label = 'Bacio',      dict = 'mp_ped_interaction', anim = 'kisses_guy_a' }
        -- aggiungi animazioni personalizzate qui
    }
}

-- ═══════════════════════════════════════════════
-- INTEGRAZIONE SISTEMA FATTURE ESTERNO
-- ═══════════════════════════════════════════════
Config.BillingResource = 'razer_billing'   -- nome risorsa fatture