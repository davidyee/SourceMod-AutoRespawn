AutoRespawn
===========

<h2>Summary:</h2>

I created this plugin based on a working respawn plugin, Player Respawn (v1.5), by bobobagan available at https://forums.alliedmods.net/showthread.php?t=108708. This plugin was released to the general public on May 24, 2014 and is available for download at https://forums.alliedmods.net/showthread.php?t=240896.

This plugin improves on Player Respawn by disabling automatic respawn if the player is killed in too short a time after respawning. Players can be killed too quickly if there is an AFK killer or auto-killer on the map (ie: in many mg_ maps) and therefore, I made this modified version of the Player Respawn plugin in an attempt to mitigate this issue.

I have only tested this plugin in Counter Strike: Global Offensive and therefore I cannot guarantee that it will work with other games.

Otherwise, this plugin works similar to the Player Respawn plugin:

<h2>Compatibility:</h2>
- Counter Strike: Source
- Counter Strike: Global Offensive
- Day of Defeat: Source
- Team Fortress 2

<h2>Requirements:</h2>
- Requires SourceMod v1.1 or greater
- Slay admin flag is required - F (or root - Z)

<h2>Cvars:</h2>
`sm_respawn_version = 1.0.2` (can not be changed)

`sm_auto_respawn` - Automatically respawn dead players (OFF - 0, On World - 1, On Enemy - 2, On Anything (Default) - 3)

`sm_auto_respawn_time` - Amount of seconds to delay the respawn by (Default 0.0 seconds)

<h2>Cmds:</h2>
sm_respawn <name | #userid> (also appears under player commands in the admin menu)

<h2>Installation:</h2>
- respawn.smx into /addons/sourcemod/plugins
- respawn.phrases.txt into /addons/sourcemod/translations
- plugin.respawn.txt into /addons/sourcemod/gamedata - Only required for DoD:S

<h2>Changelog:</h2>
- 1.0.1 (2014-07-19)
  - Fix spectator's from causing living CT/T players to freeze when they are watching them

- 1.0.0 (2014-05-24)
  - Initial release 
