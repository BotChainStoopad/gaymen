scoreboard players set #ok thesift.tmp 0
execute store success score #ok thesift.tmp in thesift:the_sift run spreadplayers ~ ~ 0 24 false @s
execute if score #ok thesift.tmp matches 0 in thesift:the_sift run tp @s ~ 180 ~
execute if score #ok thesift.tmp matches 1 at @s run function thesift:rift/arrive
title @s times 10 60 20
title @s subtitle {"text":"Strange and beautiful.","color":"#E8579F","italic":true}
title @s title {"text":"The Sift","color":"#3FC6BA","bold":true}
