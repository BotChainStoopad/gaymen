execute unless block ~ ~-1 ~ minecraft:sculk_catalyst run return run function thesift:rift/close
particle minecraft:reverse_portal ~ ~1 ~ 0.25 0.7 0.25 0.01 6
particle minecraft:dust{color:[0.25,0.9,0.82],scale:1.4} ~ ~1 ~ 0.2 0.8 0.2 0 3
particle minecraft:dust{color:[0.91,0.34,0.62],scale:1.1} ~ ~1 ~ 0.2 0.8 0.2 0 2
particle minecraft:end_rod ~ ~1.2 ~ 0.15 0.6 0.15 0.005 1
execute if predicate thesift:chance_2 run particle minecraft:sculk_charge_pop ~ ~0.1 ~ 0.4 0 0.4 0.01 2
execute if predicate thesift:chance_2 run playsound minecraft:block.amethyst_block.chime ambient @a ~ ~ ~ 0.6 0.5
