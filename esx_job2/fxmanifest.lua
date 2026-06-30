fx_version 'cerulean'
game 'gta5'

author 'TuoNome'
description 'Sistema Job2 per ESX - secondo lavoro parallelo'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}