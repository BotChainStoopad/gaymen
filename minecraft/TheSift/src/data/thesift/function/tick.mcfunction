# Open a rift: drop an Echo Shard onto a Sculk Catalyst.
execute as @e[type=item] if items entity @s contents minecraft:echo_shard at @s if block ~ ~-1 ~ minecraft:sculk_catalyst align xyz positioned ~0.5 ~ ~0.5 unless entity @e[type=marker,tag=thesift.rift,distance=..1.5] run function thesift:rift/open
execute as @e[type=marker,tag=thesift.rift] at @s run function thesift:rift/tick
scoreboard players remove @a[scores={thesift.cd=1..}] thesift.cd 1
execute as @a[gamemode=!spectator] at @s if entity @e[type=marker,tag=thesift.rift,distance=..0.9] run function thesift:rift/enter
# Ichor burns visitors, never the Sift's own creatures.
execute as @a[gamemode=!creative,gamemode=!spectator] if predicate thesift:in_ichor at @s run function thesift:ichor/burn
execute as @a unless predicate thesift:in_ichor run scoreboard players set @s thesift.ichor 9
