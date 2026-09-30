/*
 * [L4D2] Survivor Set  (EXPERIMENT)
 * The team HUD portrait follows m_survivorCharacter, and on L4D1-cast maps (survivor set 1) no number
 * shows an L4D2 survivor. In the L4D2 set (set 2) numbers 0-7 are all 8 survivors:
 *   set 2 numbers: 0 Nick, 1 Rochelle, 2 Coach, 3 Ellis, 4 Bill, 5 Zoey, 6 Francis, 7 Louis
 *
 * CLIENTS take the set from their own missions/campaignN.txt ("survivor_set"), so a server-side override
 * alone does not change their HUD (tested 2026-09-30). The L4D1 campaigns are switched to set 2 by an
 * addon (.vpk with edited mission files) that the server AND every player install. This plugin:
 *
 * 1. On the L4D1 campaigns (l4d2_survivor_set_maps), with set 2 in use, the game spawns bots as the
 *    L4D2 cast. A freshly spawned bot with an L4D2 character is turned into its L4D1 counterpart
 *    (model + name + number):
 *      Nick -> Bill (4), Rochelle -> Zoey (5), Coach -> Louis (7), Ellis -> Francis (6)
 * 2. Optional (l4d2_survivor_set_override, default off): report set 2 on set-1 maps server-side via
 *    Left4DHooks, for testing without the addon on the server.
 *
 * Humans' character numbers follow their model through l4d2_unique_survivors (Timer_SyncSurvivors).
 *
 * Character number 5 (Zoey) used to crash Windows servers; Valve has fixed that (tested on a Windows
 * server 2026-09-30). With l4d2_survivor_set_zoey5 0 the Zoey bot keeps number 1 (Rochelle's portrait),
 * for anyone who needs the old behaviour.
 *
 * Changing l4d2_survivor_set_override takes effect on the next map.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "0.3.0"
#define TEAM_SURVIVOR  2
#define SET_L4D1       1
#define SET_L4D2       2
#define NUM_MODELS     8
#define NUM_ZOEY       5

// Indexed by set-2 character number.
static const char g_sModels[NUM_MODELS][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};
static const char g_sNames[NUM_MODELS][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis" };

// L4D2 cast number (0-3) -> the L4D1 survivor who has that slot on L4D1 maps.
static const int g_iL4D1Counterpart[4] = { 4, 5, 7, 6 };

ConVar g_cvOverride;
ConVar g_cvMaps;
ConVar g_cvZoey5;
ConVar g_cvDebug;

bool g_bOverrideThisMap; // decided once per map from the override cvar
bool g_bL4D1Campaign;    // this map belongs to one of l4d2_survivor_set_maps

public Plugin myinfo =
{
	name        = "[L4D2] Survivor Set",
	author      = "forgotten893",
	description = "L4D1 maps use the L4D2 survivor set so HUD portraits can show all 8 survivors",
	version     = PLUGIN_VERSION,
	url         = ""
};

public void OnPluginStart()
{
	CreateConVar("l4d2_survivor_set_version", PLUGIN_VERSION, "Survivor Set version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvOverride = CreateConVar("l4d2_survivor_set_override", "0", "1 = also report set 2 on set-1 maps server-side (Left4DHooks). Not needed when the server has the addon. Takes effect next map.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMaps     = CreateConVar("l4d2_survivor_set_maps", "c7m,c8m,c9m,c10m,c11m,c12m,c14m", "Map name prefixes of the L4D1-cast campaigns, comma separated. Bots spawning there as the L4D2 cast become the L4D1 cast.", FCVAR_NOTIFY);
	g_cvZoey5    = CreateConVar("l4d2_survivor_set_zoey5", "1", "1 = the Zoey bot gets character number 5 (her own HUD portrait). 0 = she keeps Rochelle's number (only for old Windows builds where number 5 crashed).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDebug    = CreateConVar("l4d2_survivor_set_debug", "0", "1 = log changes to the server console", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_survivor_set");

	HookEvent("player_spawn", Event_PlayerSpawn);
	RegAdminCmd("sm_survivorset", Cmd_Status, ADMFLAG_ROOT, "Show the survivor set and every survivor's number and model");

	g_bOverrideThisMap = g_cvOverride.BoolValue;
	g_bL4D1Campaign = IsL4D1Campaign();
}

public void OnConfigsExecuted()
{
	g_bOverrideThisMap = g_cvOverride.BoolValue;
	g_bL4D1Campaign = IsL4D1Campaign();
}

public void OnMapStart()
{
	for (int m = 0; m < NUM_MODELS; m++)
	{
		PrecacheModel(g_sModels[m], true);
	}
	g_bOverrideThisMap = g_cvOverride.BoolValue;
	g_bL4D1Campaign = IsL4D1Campaign();
}

bool IsL4D1Campaign()
{
	char sMap[64], sList[256], sPrefixes[16][16];
	GetCurrentMap(sMap, sizeof(sMap));
	g_cvMaps.GetString(sList, sizeof(sList));
	int count = ExplodeString(sList, ",", sPrefixes, sizeof(sPrefixes), sizeof(sPrefixes[]));
	for (int i = 0; i < count; i++)
	{
		TrimString(sPrefixes[i]);
		if (sPrefixes[i][0] && strncmp(sMap, sPrefixes[i], strlen(sPrefixes[i]), false) == 0)
		{
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------------------------------------
// Survivor set override
// ---------------------------------------------------------------------------------------------

public Action L4D_OnGetSurvivorSet(int &retVal)
{
	return OverrideSet(retVal);
}

public Action L4D_OnFastGetSurvivorSet(int &retVal)
{
	return OverrideSet(retVal);
}

// retVal holds the game's own answer. Only L4D1 maps (set 1) are changed.
Action OverrideSet(int &retVal)
{
	if (!g_bOverrideThisMap || retVal != SET_L4D1)
	{
		return Plugin_Continue;
	}
	retVal = SET_L4D2;
	return Plugin_Handled;
}

// ---------------------------------------------------------------------------------------------
// Bots: L4D2 cast -> L4D1 cast on L4D1 maps
// ---------------------------------------------------------------------------------------------

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		// Before l4d2_unique_survivors looks at it (0.2 s), so duplicates are sorted out afterwards.
		CreateTimer(0.1, Timer_Bot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_Bot(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!g_bL4D1Campaign || L4D2_GetSurvivorSetMod() != SET_L4D2
		|| client <= 0 || !IsClientInGame(client) || !IsFakeClient(client)
		|| GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	// Only bots that spawned as the L4D2 cast: number 0-3 wearing that number's own model.
	int num = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	if (num < 0 || num > 3 || ModelIndexOf(client) != num)
	{
		return Plugin_Stop;
	}

	int target = g_iL4D1Counterpart[num];
	int newNum = target;
	if (target == NUM_ZOEY && !g_cvZoey5.BoolValue)
	{
		newNum = num; // zoey5 off: keep Rochelle's number, only look like Zoey
	}

	SetEntProp(client, Prop_Send, "m_survivorCharacter", newNum);
	SetEntityModel(client, g_sModels[target]);
	SetClientName(client, g_sNames[target]);
	ReEquipWeapons(client);

	if (g_cvDebug.BoolValue)
	{
		PrintToServer("[SurvivorSet] bot %d: %s (%d) -> %s (number %d)", client, g_sNames[num], num, g_sNames[target], newNum);
	}
	return Plugin_Stop;
}

// ---------------------------------------------------------------------------------------------

Action Cmd_Status(int client, int args)
{
	ReplyToCommand(client, "[SurvivorSet] set in use %d, map's own %d, L4D1 campaign %s, override %s",
		L4D2_GetSurvivorSetMod(), L4D2_GetSurvivorSetMap(), g_bL4D1Campaign ? "yes" : "no", g_bOverrideThisMap ? "on" : "off");
	char model[PLATFORM_MAX_PATH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			GetClientModel(i, model, sizeof(model));
			ReplyToCommand(client, "  %N%s: number %d, model %s", i, IsFakeClient(i) ? " (bot)" : "",
				GetEntProp(i, Prop_Send, "m_survivorCharacter"), model);
		}
	}
	return Plugin_Handled;
}

int ModelIndexOf(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof(model));
	for (int m = 0; m < NUM_MODELS; m++)
	{
		if (StrEqual(model, g_sModels[m], false))
		{
			return m;
		}
	}
	return -1;
}

// After a model change, held weapons keep the old model's attachment points. Dropping and
// re-equipping them re-attaches them to the new model. (Same as l4d2_unique_survivors.)
void ReEquipWeapons(int client)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	pack.WriteCell(active > MaxClients ? EntIndexToEntRef(active) : INVALID_ENT_REFERENCE);

	int weapons[5], count;
	for (int slot = 0; slot <= 4; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon > MaxClients && IsValidEntity(weapon))
		{
			weapons[count++] = weapon;
		}
	}

	pack.WriteCell(count);
	for (int n = 0; n < count; n++)
	{
		SDKHooks_DropWeapon(client, weapons[n], NULL_VECTOR, NULL_VECTOR);
		pack.WriteCell(EntIndexToEntRef(weapons[n]));
	}
	CreateTimer(0.1, Timer_ReEquip, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
}

Action Timer_ReEquip(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int activeRef = pack.ReadCell();
	int count = pack.ReadCell();

	for (int n = 0; n < count; n++)
	{
		int weapon = EntRefToEntIndex(pack.ReadCell());
		if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && weapon > MaxClients && IsValidEntity(weapon))
		{
			EquipPlayerWeapon(client, weapon);
		}
	}

	int active = EntRefToEntIndex(activeRef);
	if (client > 0 && IsClientInGame(client) && active > MaxClients && IsValidEntity(active))
	{
		char cls[64];
		GetEntityClassname(active, cls, sizeof(cls));
		FakeClientCommand(client, "use %s", cls);
	}
	return Plugin_Stop;
}
