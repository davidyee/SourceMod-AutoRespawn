/**
 * Auto Respawn V1.2.0
 * By David Y.
 * Modified from bobobagan's Player Respawn plugin V1.5 at
 * https://forums.alliedmods.net/showthread.php?t=108708
 * Repeat kill fix inspired by Repeat Kill Detector V1.02 by GoD-Tony at
 * https://forums.alliedmods.net/showthread.php?p=1504018
 *
 * Fixes auto-respawn infinite killing on maps with AFK or auto spawn killers.
 * Disables auto-respawn if the same player dies consecutively in too short a 
 * period of time. The plugin also takes into account the spawn delay when 
 * determining whether or not to disable the respawn for the current round.
 *
 * You may allow respawning if the world kills the player (sm_auto_respawn 1) or
 * if enemies kill the player (sm_auto_respawn 2) or if anything kills the player 
 * (sm_auto_respawn 3).
 *
 * You may allow auto-respawn disabling on AFK or auto spawn killers on a per
 * player basis (sm_auto_spawn_type 1) or for all players once a single player 
 * is killed by a repeat spawn killer (sm_auto_spawn_type 0).
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <tf2>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#include <adminmenu>

Handle hAdminMenu = null;
Handle g_hPlayerRespawn;
Handle g_hGameConfig;

// This will be used for checking which team the player is on before respawning them
#define SPECTATOR_TEAM 0
#define TEAM_SPEC      1
#define TEAM_1         2
#define TEAM_2         3

// If players are being killed faster than the time below in seconds, then turn off the respawner
#define REPEAT_KILLER_TIME 1.0

Handle sm_auto_respawn = null;
Handle sm_auto_respawn_time = null;
Handle sm_auto_respawn_type = null;
Handle sm_auto_respawn_bots = null;
Handle AutorespawnTimer[MAXPLAYERS+1];
float LastDeath[MAXPLAYERS+1];
bool BlockRespawn[MAXPLAYERS+1];
bool isRepeatKillerPresent = false;

public Plugin:myinfo = {
	name = "Auto Respawn",
	author = "David Y.",
	description = "Respawn dead players back to their spawns and disable if there is an auto-killer",
	version = "1.2.0",
	url = "https://forums.alliedmods.net/showthread.php?p=2166294"
}

public void OnPluginStart() {
	CreateConVar("sm_respawn_version", "1.2.0", "Player AutoRespawn Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	sm_auto_respawn = CreateConVar("sm_auto_respawn", "3", "Disable/World/Enemy/Always (0/1/2/3) respawn player on death");
	sm_auto_respawn_time = CreateConVar("sm_auto_respawn_time", "0.0", "How many seconds to delay the respawn");
	sm_auto_respawn_type = CreateConVar("sm_auto_respawn_type", "0", "Respawn type; 0 - disable respawn for all players, 1 - disable respawn per player");
	sm_auto_respawn_bots = CreateConVar("sm_auto_respawn_bots", "1", "Disable/Enable (0/1) respawn bots on death");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "sm_respawn <#userid|name>");

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
		OnAdminMenuReady(topmenu);
	}

	char game[40];
	GetGameFolderName(game, sizeof(game));
	if (StrEqual(game, "dod")) {
		// Next 14 lines of text are taken from Andersso's DoDs respawn plugin. Thanks :)
		g_hGameConfig = LoadGameConfigFile("plugin.respawn");

		if (g_hGameConfig == null) {
			SetFailState("Fatal Error: Missing File \"plugin.respawn\"!");
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "DODRespawn");
		g_hPlayerRespawn = EndPrepSDKCall();

		if (g_hPlayerRespawn == null) {
			SetFailState("Fatal Error: Unable to find signature for \"CDODPlayer::DODRespawn(void)\"!");
		}
	}

	LoadTranslations("common.phrases");
	LoadTranslations("respawn.phrases");
	AutoExecConfig(true, "respawn");
}

public Action Command_Respawn(client, args) {
	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: sm_respawn <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	new target_list[MaxClients], target_count, bool:tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_DEAD,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE) {	// If we don't have dead players
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Team filter dead players, re-order target_list array with new_target_count
	int target, team, new_target_count;

	for (int i = 0; i < target_count; i++) {
		target = target_list[i];
		team = GetClientTeam(target);

		if(team >= 2) {
			target_list[new_target_count] = target; // re-order
			new_target_count++;
		}
	}

	if(new_target_count == COMMAND_TARGET_NONE) { // No dead players from  team 2 and 3
		ReplyToTargetError(client, new_target_count);
		return Plugin_Handled;
	}

	target_count = new_target_count; // re-set new value.

	if (tn_is_ml) {
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", target_name);
	} else {
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", "_s", target_name);
	}

	for (int i = 0; i < target_count; i++) {
		RespawnPlayer(client, target_list[i]);
	}

	return Plugin_Handled;
}

public bool OnClientConnect(client, char[] rejectmsg, maxlen)
{
	LastDeath[client] = 0.0;
	BlockRespawn[client] = false;
	return true;
}

public void OnClientDisconnect(int client)
{
	delete AutorespawnTimer[client];
	LastDeath[client] = 0.0;
	BlockRespawn[client] = false;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
	for(int client=1; client<=MAXPLAYERS; client++) {
		BlockRespawn[client] = false;
	}
	isRepeatKillerPresent = false;
	return Plugin_Continue;
}

public Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int pluginState = GetConVarInt(sm_auto_respawn);
	int respawnType = GetConVarInt(sm_auto_respawn_type);
	if (pluginState > 0) {
		// get event info
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if(respawnType) { // disable respawn per player
			if(BlockRespawn[client]) return; 
		} else { // disable for everyone
			if(isRepeatKillerPresent) return;
		}
		
		int team = GetClientTeam(client);
		int attackerId = GetEventInt(event, "attacker");
		int attacker = GetClientOfUserId(attackerId);
		
		char weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		// uncomment to record if trap is specifically the killer
		// bool isTrapKiller = client && !attacker && StrEqual(weapon, "trigger_hurt");
		bool isWorldKiller = client && !attacker;
		bool isEnemyKiller = client && attacker;
		if ((isWorldKiller && pluginState == 1) || (isEnemyKiller && pluginState == 2) || pluginState == 3) {
			float fGameTime = GetGameTime();
			float respawnTime = GetConVarFloat(sm_auto_respawn_time);
			
			if ((fGameTime - LastDeath[client] - respawnTime) < REPEAT_KILLER_TIME) {
				if(respawnType) {
					PrintToChat(client, "[SM] Repeat killer detected. Your auto respawn has been disabled for this round.");
				} else {
					PrintToChatAll("[SM] Repeat killer detected. Disabling respawn for this round.");
				}
				
				BlockRespawn[client] = true;
				isRepeatKillerPresent = true;
			}
			else {
				// create the respawn for CTs or Ts
				if(IsClientInGame(client) && (team == TEAM_1 || team == TEAM_2)) {
					int botSpawn = GetConVarInt(sm_auto_respawn_bots);
					bool isBot = IsFakeClient(client);
					bool isHuman = !isBot;
					bool isBotSpawnOk = botSpawn && isBot;
					
					if(isHuman || isBotSpawnOk) {
						AutorespawnTimer[client] = CreateTimer(GetConVarFloat(sm_auto_respawn_time), RespawnPlayer2, client, TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
			LastDeath[client] = fGameTime; // store the current time for the given player for next calculation
		}
	}
}

public RespawnPlayer(client, target) {
	char game[40];
	GetGameFolderName(game, sizeof(game));
	LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
	BlockRespawn[target] = false;

	if(StrEqual(game, "cstrike") || StrEqual(game, "csgo")) {
		CS_RespawnPlayer(target);
	} else if (StrEqual(game, "tf")) {
		TF2_RespawnPlayer(target);
	} else if (StrEqual(game, "dod")) {
		SDKCall(g_hPlayerRespawn, target);
	}
}

public Action RespawnPlayer2(Handle Timer, any:client) {
	char game[40];
	GetGameFolderName(game, sizeof(game));

	if(StrEqual(game, "cstrike") || StrEqual(game, "csgo")) {
		// bug fix:
		// do no attempt to respawn CS_TEAM_NONE or CS_TEAM_SPECTATOR
		// spectators cause the spectated player to freeze
		int team = GetClientTeam(client);
		if(team == CS_TEAM_T || team == CS_TEAM_CT) {
			CS_RespawnPlayer(client);
		}
	} else if (StrEqual(game, "tf")) {
		TF2_RespawnPlayer(client);
	} else if (StrEqual(game, "dod")) {
		SDKCall(g_hPlayerRespawn, client);
	}
	AutorespawnTimer[client] = null;
}

public OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "adminmenu")) {
		hAdminMenu = null;
	}
}

public OnAdminMenuReady(Handle topmenu) {
	if (topmenu == hAdminMenu) {
		return;
	}
	
	hAdminMenu = topmenu;
	new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT) {
		AddToTopMenu(hAdminMenu,
		"sm_respawn",
		TopMenuObject_Item,
		AdminMenu_Respawn,
		player_commands,
		"sm_respawn",
		ADMFLAG_SLAY);
	}
}

public AdminMenu_Respawn( Handle topmenu, TopMenuAction:action, TopMenuObject:object_id, param, char[] buffer, maxlength ) {
	if (action == TopMenuAction_DisplayOption) {
		Format(buffer, maxlength, "Respawn Player");
	} else if( action == TopMenuAction_SelectOption) {
		DisplayPlayerMenu(param);
	}
}

DisplayPlayerMenu(client) {
	Handle menu = CreateMenu(MenuHandler_Players);

	char title[100];
	Format(title, sizeof(title), "Choose Player to Respawn:");
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);

	// AddTargetsToMenu(menu, client, true, false);
	// Lets only add dead players to the menu... we don't want to respawn alive players do we?
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_DEAD);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Players(Handle menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_End) {
		CloseHandle(menu);
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && hAdminMenu != null) {
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select) {
		char info[32];
		int userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0) {
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		} else if (!CanUserTarget(param1, target)) {
			PrintToChat(param1, "[SM] %t", "Unable to target");
		} else {
			char name[32];
			GetClientName(target, name, sizeof(name));

			RespawnPlayer(param1, target);
			ShowActivity2(param1, "[SM] ", "%t", "Toggled respawn on target", "_s", name);
		}

		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
			DisplayPlayerMenu(param1);
		}
	}
}
