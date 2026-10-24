scoreboard players set #ok thesift.tmp 0
execute store success score #ok thesift.tmp in minecraft:overworld run spreadplayers ~ ~ 0 24 false @s
execute if score #ok thesift.tmp matches 0 in minecraft:overworld run tp @s ~ 200 ~
execute if score #ok thesift.tmp matches 1 at @s run function thesift:rift/arrive
