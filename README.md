AutoRespawn
===========

Summary:
I created this plugin based on a working respawn plugin, Player Respawn (v1.5), by bobobagan available at https://forums.alliedmods.net/showthread.php?t=108708.

This plugin improves on Player Respawn by disabling automatic respawn if the player is killed in too short a time after respawning. Players can be killed too quickly if there is an AFK killer or auto-killer on the map (ie: in many mg_ maps) and therefore, I made this modified version of the Player Respawn plugin in an attempt to mitigate this issue.

I have only tested this plugin in Counter Strike: Global Offensive and therefore I cannot guarantee that it will work with other games.

Otherwise, this plugin works similar to the Player Respawn plugin:

Compatibility:
- Counter Strike: Source
- Counter Strike: Global Offensive
- Day of Defeat: Source
- Team Fortress 2

Requirements:
- Requires SourceMod v1.1 or greater
- Slay admin flag is required - F (or root - Z)

Cvars:
sm_respawn_version = 1.0 (can not be changed)
sm_auto_respawn - Automatically respawn dead players (Default 0)
sm_auto_respawn_time - Amount of seconds to delay the respawn by (Default 0 seconds)

Cmds:
sm_respawn <name | #userid> (also appears under player commands in the admin menu)

Installation:
- respawn.smx into /addons/sourcemod/plugins
- respawn.phrases.txt into /addons/sourcemod/translations
- plugin.respawn.txt into /addons/sourcemod/gamedata - Only required for DoD:S