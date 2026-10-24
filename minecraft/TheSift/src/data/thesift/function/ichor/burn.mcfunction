scoreboard players add @s thesift.ichor 1
particle minecraft:dust{color:[0.91,0.34,0.62],scale:1.2} ~ ~0.6 ~ 0.3 0.4 0.3 0 4
particle minecraft:flame ~ ~0.4 ~ 0.25 0.2 0.25 0.01 1
execute if score @s thesift.ichor matches 10.. run function thesift:ichor/hurt
