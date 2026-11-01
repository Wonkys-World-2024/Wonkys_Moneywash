-- Merge these entries INSIDE the return table in ox_inventory/data/items.lua.
-- Add black_money only if it does not already exist on your server.
['black_money'] = { label = 'Dirty Money', weight = 0, stack = true, close = true, description = 'Cash requiring laundering.' },
['ww_wet_cash'] = { label = 'Wet Money Bundle', weight = 1000, stack = false, close = true, description = 'Washed notes. Must be dried before collection.' },
['ww_wash_tablet'] = { label = 'Wonkys Wash Tablet', consume = 0, weight = 500, stack = false, close = true, description = 'Rent a washer and dryer. Manage your Wonkys Wash booking.', client = { image = 'ww_wash_tablet.png', export = 'Wonkys_MoneyWash.openTablet' } },
