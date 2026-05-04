fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot & Stevie'
description 'Allows players to sell hotdogs to npcs for money'
version '2.0.0'

ui_page 'html/ui.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    'client/main.lua'
}

server_script 'server/main.lua'

files {
    'html/ui.html',
    'html/ui.css',
    'html/ui.js',
    'html/icon.png',
}
