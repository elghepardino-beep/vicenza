fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RAZER ROLEPLAY'
description 'Menu Personale F5 Ultra Moderno'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
    'client/radio.lua'
}

server_scripts {
    'server/main.lua',
    'server/admin.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/sounds/*.ogg',
    'html/img/*.png'
}