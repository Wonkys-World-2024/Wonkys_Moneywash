fx_version 'cerulean'
game 'gta5'
author 'Wonky World'
description 'Two-stage persistent laundromat money washing for Qbox'
version '1.4.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'handling.lua', 'client.lua', 'visuals.lua', 'tablet.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
dependencies { 'qbx_core', 'ox_lib', 'ox_target', 'ox_inventory', 'oxmysql', 'bzzz_money' }

ui_page 'web/index.html'
files { 'web/*' }
