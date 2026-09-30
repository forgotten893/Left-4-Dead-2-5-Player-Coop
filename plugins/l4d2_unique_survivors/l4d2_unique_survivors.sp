/*
 * [L4D2] Unique Survivors
 * The team HUD tracks teammates by their survivor character number (m_survivorCharacter), so two
 * survivors with the same number (e.g. "Ellis" and "(1)Ellis") share one HUD slot. This plugin keeps
 * survivor BOTS from duplicating anyone: a bot whose character number is already in use gets an
 * unused number, plus a model and name nobody else has. Humans are never given another model.
 *
 * Every survivor's character number also follows their model (Timer_SyncSurvivors), so the HUD shows
 * the survivor they look like after !csm / !csc. Teammate portraits are redrawn by reloading
 * HUD Display Manager.
 *
 * Character numbers depend on the map's survivor set:
 *   L4D2 cast maps: 0 Nick, 1 Rochelle, 2 Coach, 3 Ellis, 4 Bill, 5 Zoey, 6 Francis, 7 Louis
 *   L4D1 cast maps: 0 Bill, 1 Zoey, 2 Louis, 3 Francis (4-7 are extra numbers for the same cast)
 * Zoey (number 5 in the L4D2 set) used to crash Windows servers; Valve has fixed that (tested on a
 * Windows server 2026-09-30), so she is used like everyone else. l4d2_unique_survivors_zoey5 0 still
 * keeps number 5 and Zoey's model out of use, for anyone who needs the old behaviour.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.4.0"
#define TEAM_SURVIVOR  2
#define SET_L4D1       1
#define NUM_CHARS      8
#define NUM_MODELS     8

enum
{
	M_NICK, M_ROCHELLE, M_COACH, M_ELLIS, M_BILL, M_ZOEY, M_FRANCIS, M_LOUIS
}

static const char g_sModelNames[NUM_MODELS][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis" };
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

// Which model each character number naturally uses, per survivor set.
static const int g_iNaturalModelL4D2[NUM_CHARS] = { M_NICK, M_ROCHELLE, M_COACH, M_ELLIS, M_BILL, M_ZOEY, M_FRANCIS, M_LOUIS };
static const int g_iNaturalModelL4D1[NUM_CHARS] = { M_BILL, M_ZOEY, M_LOUIS, M_FRANCIS, M_BILL, M_ZOEY, M_FRANCIS, M_LOUIS };

// Free character numbers to hand out, in order of preference. Zoey's number (5 in the L4D2 set, 1 in
// the L4D1 set) is skipped when l4d2_unique_survivors_zoey5 is 0 (see IsZoeyNumber).
static const int g_iNumbersL4D2Map[] = { 4, 7, 6, 5, 0, 1, 2, 3 };
static const int g_iNumbersL4D1Map[] = { 4, 7, 6, 0, 1, 2, 3 };

// Fallback models when a number's natural model is already worn by someone. Zoey's model is skipped
// when l4d2_unique_survivors_zoey5 is 0.
static const int g_iModelsL4D2Map[] = { M_BILL, M_LOUIS, M_FRANCIS, M_ZOEY, M_NICK, M_ELLIS, M_COACH, M_ROCHELLE };
static const int g_iModelsL4D1Map[] = { M_NICK, M_ELLIS, M_COACH, M_ROCHELLE, M_BILL, M_ZOEY, M_LOUIS, M_FRANCIS };

ConVar g_cvEnabled;
ConVar g_cvZoey5;
bool g_bHudRefreshPending;

public Plugin myinfo =
{
	name        = "[L4D2] Unique Survivors",
	author      = "forgotten893",
	description = "Gives survivor bots that duplicate another survivor's character an unused one",
	version     = PLUGIN_VERSION,
	url         = ""
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("l4d2_unique_survivors_enable", "1", "Switch duplicate-character survivor bots to an unused character (0 = off).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvZoey5   = CreateConVar("l4d2_unique_survivors_zoey5", "1", "1 = Zoey is used like everyone else (number 5, her own HUD portrait). 0 = never use Zoey's number or model (only for old Windows builds where number 5 crashed).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_unique_survivors");

	HookEvent("round_start",  Event_RoundStart,  EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);

	RegAdminCmd("sm_uniquecheck", Cmd_Check, ADMFLAG_ROOT, "Run the duplicate-survivor check now and print the survivor list");
}

public void OnMapStart()
{
	for (int m = 0; m < NUM_MODELS; m++)
		PrecacheModel(g_sModels[m], true);

	g_bHudRefreshPending = false;

	// Safety net: catches duplicates created any other way (e.g. a player picking a bot's character).
	CreateTimer(5.0, Timer_Periodic, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Survivor Chat Select's !csm / !csc change a survivor's model but not their name or character number.
	CreateTimer(1.0, Timer_SyncSurvivors, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

// Makes survivors match their model (after !csm, or a bot changed with !csc). The HUD portrait and label
// come from the character number, so everyone gets their model's number when this map's set has one
// for it (L4D1 maps only have numbers for the L4D1 cast; Zoey's only with l4d2_unique_survivors_zoey5):
// - humans first: they take the number unless another human has it. A bot holding it is moved to
//   another character by FixDuplicates right away.
// - bots: take the number only if nobody has it. They're also renamed to the model's survivor; a name
//   containing it ("(1)Ellis") counts as matching, so the game's duplicate-name numbering is left alone.
Action Timer_SyncSurvivors(Handle timer)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;

	bool l4d1Map = L4D2_GetSurvivorSetMod() == SET_L4D1;

	bool humanTaken[NUM_CHARS];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i) || IsFakeClient(i))
			continue;
		int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		if (c >= 0 && c < NUM_CHARS)
			humanTaken[c] = true;
	}

	bool humanChanged = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i) || IsFakeClient(i))
			continue;

		int m = ModelIndexOf(i);
		if (m == -1)
			continue;

		int want = NumberForModel(m, l4d1Map);
		int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		if (want != -1 && want != c && !humanTaken[want])
		{
			SetEntProp(i, Prop_Send, "m_survivorCharacter", want);
			if (c >= 0 && c < NUM_CHARS)
				humanTaken[c] = false;
			humanTaken[want] = true;
			ReEquipWeapons(i);
			humanChanged = true;
		}
	}
	if (humanChanged)
	{
		FixDuplicates(); // bots that had a number a human just took
		RequestHudRefresh();
	}

	bool numberTaken[NUM_CHARS];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i))
			continue;
		int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		if (c >= 0 && c < NUM_CHARS)
			numberTaken[c] = true;
	}

	char name[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i) || !IsFakeClient(i))
			continue;

		int m = ModelIndexOf(i);
		if (m == -1)
			continue;

		GetClientName(i, name, sizeof(name));
		if (StrContains(name, g_sModelNames[m], false) == -1)
			SetClientName(i, g_sModelNames[m]);

		int want = NumberForModel(m, l4d1Map);
		int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		if (want != -1 && want != c && !numberTaken[want])
		{
			SetEntProp(i, Prop_Send, "m_survivorCharacter", want);
			if (c >= 0 && c < NUM_CHARS)
				numberTaken[c] = false;
			numberTaken[want] = true;
			ReEquipWeapons(i);
			RequestHudRefresh();
		}
	}
	return Plugin_Continue;
}

// Clients draw a teammate's HUD portrait when the teammate enters a HUD slot and don't redraw it when
// the character number changes. Reloading HUD Display Manager rebuilds the HUD list, which redraws
// the portraits (same as its !resethud, without the cooldown). Several changes in a row -> one reload.
void RequestHudRefresh()
{
	if (g_bHudRefreshPending)
		return;
	g_bHudRefreshPending = true;
	CreateTimer(0.5, Timer_HudRefresh, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_HudRefresh(Handle timer)
{
	g_bHudRefreshPending = false;
	if (FindPluginByFile("l4d2_hud_display_manager.smx") != null)
		ServerCommand("sm plugins reload l4d2_hud_display_manager");
	return Plugin_Stop;
}

// The character number that shows this model's survivor on the HUD, or -1 if the set has none
// (L4D2 survivors on L4D1 maps) or it is 5 and l4d2_unique_survivors_zoey5 is off.
int NumberForModel(int model, bool l4d1Map)
{
	if (l4d1Map)
	{
		switch (model)
		{
			case M_BILL:    return 0;
			case M_ZOEY:    return 1;
			case M_LOUIS:   return 2;
			case M_FRANCIS: return 3;
		}
		return -1;
	}
	if (model == M_ZOEY && !g_cvZoey5.BoolValue)
		return -1;
	return model; // L4D2 set numbers are in model order
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// l4dmultislots spawns the extra survivors shortly after the round starts.
	CreateTimer(3.0, Timer_Check, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// New bots grab an unused character almost immediately; the second check catches anything
	// l4dmultislots adjusts right after spawning the bot.
	if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		CreateTimer(0.2, Timer_Check, _, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.5, Timer_Check, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_Check(Handle timer)
{
	FixDuplicates();
	return Plugin_Stop;
}

Action Timer_Periodic(Handle timer)
{
	FixDuplicates();
	return Plugin_Continue;
}

Action Cmd_Check(int client, int args)
{
	int changed = FixDuplicates();
	ReplyToCommand(client, "[Unique Survivors] Changed %d bot(s). Survivor set: %d (map's own: %d).", changed, L4D2_GetSurvivorSetMod(), L4D2_GetSurvivorSetMap());
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i))
			continue;
		char model[PLATFORM_MAX_PATH];
		GetClientModel(i, model, sizeof(model));
		ReplyToCommand(client, "  %N%s: character %d, model %s", i, IsFakeClient(i) ? " (bot)" : "", GetEntProp(i, Prop_Send, "m_survivorCharacter"), model);
	}
	return Plugin_Handled;
}

bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

int ModelIndexOf(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof(model));
	for (int m = 0; m < NUM_MODELS; m++)
	{
		if (StrEqual(model, g_sModels[m], false))
			return m;
	}
	return -1;
}

// Returns how many bots were switched.
int FixDuplicates()
{
	if (!g_cvEnabled.BoolValue)
		return 0;

	bool numberTaken[NUM_CHARS], modelTaken[NUM_MODELS];

	// Everyone's model counts as taken; humans claim their character numbers first.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i))
			continue;

		int m = ModelIndexOf(i);
		if (m != -1)
			modelTaken[m] = true;

		if (!IsFakeClient(i))
		{
			int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
			if (c >= 0 && c < NUM_CHARS)
				numberTaken[c] = true;
		}
	}

	// The set in use, not the map's own: l4d2_survivor_set can switch L4D1 maps to the L4D2 set.
	bool l4d1Map = L4D2_GetSurvivorSetMod() == SET_L4D1;
	int changed;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsSurvivor(i) || !IsFakeClient(i))
			continue;

		int c = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		if (c < 0 || c >= NUM_CHARS)
			continue;

		if (!numberTaken[c])
		{
			numberTaken[c] = true;
			continue;
		}

		int newNumber = PickNumber(numberTaken, l4d1Map);
		if (newNumber == -1)
			break; // every usable character number is in use

		// The bot's old model stays marked as taken because the other survivor still wears it.
		int newModel = PickModel(newNumber, modelTaken, l4d1Map);
		SetCharacter(i, newNumber, newModel);
		numberTaken[newNumber] = true;
		modelTaken[newModel] = true;
		changed++;
	}
	return changed;
}

// Zoey's own number in this survivor set.
bool IsZoeyNumber(int number, bool l4d1Map)
{
	return number == (l4d1Map ? 1 : 5);
}

int PickNumber(const bool[] numberTaken, bool l4d1Map)
{
	bool zoey = g_cvZoey5.BoolValue;
	int count = l4d1Map ? sizeof(g_iNumbersL4D1Map) : sizeof(g_iNumbersL4D2Map);
	for (int n = 0; n < count; n++)
	{
		int c = l4d1Map ? g_iNumbersL4D1Map[n] : g_iNumbersL4D2Map[n];
		if (!zoey && IsZoeyNumber(c, l4d1Map))
			continue;
		if (!numberTaken[c])
			return c;
	}
	return -1;
}

int PickModel(int number, const bool[] modelTaken, bool l4d1Map)
{
	bool zoey = g_cvZoey5.BoolValue;
	int natural = l4d1Map ? g_iNaturalModelL4D1[number] : g_iNaturalModelL4D2[number];
	if ((zoey || natural != M_ZOEY) && !modelTaken[natural])
		return natural;

	int count = l4d1Map ? sizeof(g_iModelsL4D1Map) : sizeof(g_iModelsL4D2Map);
	for (int n = 0; n < count; n++)
	{
		int m = l4d1Map ? g_iModelsL4D1Map[n] : g_iModelsL4D2Map[n];
		if (!zoey && m == M_ZOEY)
			continue;
		if (!modelTaken[m])
			return m;
	}
	// Everything worn already: keep the number's own look.
	return (!zoey && natural == M_ZOEY) ? M_BILL : natural;
}

void SetCharacter(int client, int number, int model)
{
	SetEntProp(client, Prop_Send, "m_survivorCharacter", number);
	SetEntityModel(client, g_sModels[model]);
	SetClientName(client, g_sModelNames[model]);
	ReEquipWeapons(client);
	RequestHudRefresh();
}

// After a model change, held weapons keep the old model's attachment points. Dropping and
// re-equipping them re-attaches them to the new model.
void ReEquipWeapons(int client)
{
	if (!IsPlayerAlive(client))
		return;

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	pack.WriteCell(active > MaxClients ? EntIndexToEntRef(active) : INVALID_ENT_REFERENCE);

	int weapons[5], count;
	for (int slot = 0; slot <= 4; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon > MaxClients && IsValidEntity(weapon))
			weapons[count++] = weapon;
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
			EquipPlayerWeapon(client, weapon);
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
