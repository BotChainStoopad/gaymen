execute if score @s thesift.cd matches 1.. run return run scoreboard players set @s thesift.cd 40
scoreboard players set @s thesift.cd 60
effect give @s minecraft:darkness 3 0 true
effect give @s minecraft:slow_falling 8 0 true
playsound minecraft:entity.warden.sonic_charge player @s ~ ~ ~ 1 1.4
execute if dimension thesift:the_sift run return run function thesift:rift/to_overworld
function thesift:rift/to_sift
