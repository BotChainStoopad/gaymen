summon minecraft:marker ~ ~ ~ {Tags:["thesift.rift"]}
playsound minecraft:block.sculk_shrieker.shriek block @a ~ ~ ~ 1.5 0.6
playsound minecraft:block.respawn_anchor.charge block @a ~ ~ ~ 1 0.5
particle minecraft:sonic_boom ~ ~1 ~ 0 0 0 0 1
particle minecraft:sculk_soul ~ ~1 ~ 0.4 1 0.4 0.05 60
advancement grant @a[distance=..8] only thesift:open_rift
execute store result score #count thesift.tmp run data get entity @s Item.count
scoreboard players remove #count thesift.tmp 1
execute if score #count thesift.tmp matches ..0 run return run kill @s
execute store result entity @s Item.count int 1 run scoreboard players get #count thesift.tmp
