fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ian.trm'
description 'DV Basesystem - In Entwicklung'
version '1.0b'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',     -- NEU: Im shared Ordner
    'shared/structures.lua'  -- NEU: Im shared Ordner
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

exports {
    'startPlacing'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}