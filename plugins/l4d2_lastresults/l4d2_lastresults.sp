/*
 * [L4D2] Last Chapter Results
 * The end-of-chapter screen only has room for 4 survivors. This plugin reads the game's own
 * per-player chapter stats (the m_checkpoint* netprops the end screen is built from) for every
 * survivor, bots included, snapshots them when the chapter ends, and shows them with
 * !lastresults / !slr. !results / !sr shows the current chapter so far.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.0.0"
#define TEAM_SURVIVOR  2
#define MAX_ROWS       16

// Indexes into m_checkpointZombieKills (by zombie class).
#define ZK_COMMON 0
#define ZK_WITCH  7
#define ZK_TANK   8

enum
{
	ST_COMMON,     // common infected killed
	ST_SPECIAL,    // special infected killed (smoker..charger)
	ST_TANKKILLS,  // tanks killed
	ST_WITCHKILLS, // witches killed
	ST_HEADSHOT,   // headshots
	ST_MELEE,      // melee kills
	ST_TANKDMG,    // damage dealt to tanks
	ST_WITCHDMG,   // damage dealt to witches
	ST_FF,         // friendly fire damage dealt to other survivors
	ST_TAKEN,      // damage taken
	ST_INCAP,      // times incapacitated
	ST_DEATHS,     // deaths
	ST_REVIVE,     // teammates revived
	ST_HEAL,       // first aid kits used on teammates
	ST_COUNT
}

// End-of-chapter highlights, in the game's own wording.
enum struct Highlight
{
	char title[32];
	int  stat;
	bool lowest;   // true = fewest wins (e.g. least damage taken)
}

Highlight g_Highlights[11];

bool g_bHaveLast;
bool g_bSnapshotTaken;
int  g_iLastCount;
int  g_iLastStats[MAX_ROWS][ST_COUNT];
char g_sLastNames[MAX_ROWS][MAX_NAME_LENGTH];
char g_sLastMap[64];
char g_sLastOutcome[32];

ConVar g_cvAnnounce;

public Plugin myinfo =
{
	name        = "[L4D2] Last Chapter Results",
	author      = "forgotten893",
	description = "Shows every survivor's end-of-chapter stats with !lastresults",
	version     = PLUGIN_VERSION,
	url         = ""
};

public void OnPluginStart()
{
	g_cvAnnounce = CreateConVar("l4d2_lastresults_announce", "1", "Remind players about !lastresults after a new chapter loads (0 = off).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_lastresults");

	HookEvent("round_start",    Event_RoundStart,    EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("finale_win",     Event_FinaleWin,     EventHookMode_PostNoCopy);
	HookEvent("mission_lost",   Event_MissionLost,   EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_lastresults", Cmd_LastResults, "Show every survivor's stats from the previous chapter");
	RegConsoleCmd("sm_results",     Cmd_Results,     "Show every survivor's stats for the current chapter so far");
	RegConsoleCmd("sm_slr",         Cmd_LastResults, "Alias of sm_lastresults");
	RegConsoleCmd("sm_sr",          Cmd_Results,     "Alias of sm_results");

	AddHighlight(0,  "GENERAL DEFENSE",       ST_COMMON,   false);
	AddHighlight(1,  "SPECIAL KILLER",        ST_SPECIAL,  false);
	AddHighlight(2,  "TANK SLAYER",           ST_TANKDMG,  false);
	AddHighlight(3,  "WITCH HUNTER",          ST_WITCHDMG, false);
	AddHighlight(4,  "HEADHUNTER",            ST_HEADSHOT, false);
	AddHighlight(5,  "MELEE FIGHTER",         ST_MELEE,    false);
	AddHighlight(6,  "TEAM MEDIC",            ST_HEAL,     false);
	AddHighlight(7,  "GREATEST SAVIOR",       ST_REVIVE,   false);
	AddHighlight(8,  "LEAST DAMAGE TAKEN",    ST_TAKEN,    true);
	AddHighlight(9,  "FEWEST INCAPS",         ST_INCAP,    true);
	AddHighlight(10, "MOST CAREFUL TEAMMATE", ST_FF,       true);
}

void AddHighlight(int index, const char[] title, int stat, bool lowest)
{
	strcopy(g_Highlights[index].title, sizeof(Highlight::title), title);
	g_Highlights[index].stat = stat;
	g_Highlights[index].lowest = lowest;
}

// ---------------------------------------------------------------------------
// Reading the game's chapter stats
// ---------------------------------------------------------------------------

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

void ReadStats(int client, int stats[ST_COUNT])
{
	stats[ST_COMMON]     = GetEntProp(client, Prop_Send, "m_checkpointZombieKills", _, ZK_COMMON);
	stats[ST_SPECIAL]    = 0;
	for (int zc = 1; zc <= 6; zc++)
		stats[ST_SPECIAL] += GetEntProp(client, Prop_Send, "m_checkpointZombieKills", _, zc);
	stats[ST_WITCHKILLS] = GetEntProp(client, Prop_Send, "m_checkpointZombieKills", _, ZK_WITCH);
	stats[ST_TANKKILLS]  = GetEntProp(client, Prop_Send, "m_checkpointZombieKills", _, ZK_TANK);
	stats[ST_HEADSHOT]   = GetEntProp(client, Prop_Send, "m_checkpointHeadshots");
	stats[ST_MELEE]      = GetEntProp(client, Prop_Send, "m_checkpointMeleeKills");
	stats[ST_TANKDMG]    = GetEntProp(client, Prop_Send, "m_checkpointDamageToTank");
	stats[ST_WITCHDMG]   = GetEntProp(client, Prop_Send, "m_checkpointDamageToWitch");
	stats[ST_FF]         = GetEntProp(client, Prop_Send, "m_checkpointSurvivorDamage");
	stats[ST_TAKEN]      = GetEntProp(client, Prop_Send, "m_checkpointDamageTaken");
	stats[ST_INCAP]      = GetEntProp(client, Prop_Send, "m_checkpointIncaps");
	stats[ST_DEATHS]     = GetEntProp(client, Prop_Send, "m_checkpointDeaths");
	stats[ST_REVIVE]     = GetEntProp(client, Prop_Send, "m_checkpointReviveOtherCount");
	stats[ST_HEAL]       = GetEntProp(client, Prop_Send, "m_checkpointFirstAidShared");
}

// Copies every survivor's current chapter stats into the arrays, sorted by common kills.
int CollectRows(char names[MAX_ROWS][MAX_NAME_LENGTH], int stats[MAX_ROWS][ST_COUNT])
{
	int count;
	for (int i = 1; i <= MaxClients && count < MAX_ROWS; i++)
	{
		if (!IsSurvivor(i))
			continue;

		GetClientName(i, names[count], MAX_NAME_LENGTH);
		ReadStats(i, stats[count]);
		count++;
	}

	for (int a = 1; a < count; a++)
	{
		for (int b = a; b > 0 && stats[b][ST_COMMON] > stats[b - 1][ST_COMMON]; b--)
		{
			char tmpName[MAX_NAME_LENGTH];
			strcopy(tmpName, sizeof(tmpName), names[b]);
			strcopy(names[b], MAX_NAME_LENGTH, names[b - 1]);
			strcopy(names[b - 1], MAX_NAME_LENGTH, tmpName);

			for (int s = 0; s < ST_COUNT; s++)
			{
				int tmp = stats[b][s];
				stats[b][s] = stats[b - 1][s];
				stats[b - 1][s] = tmp;
			}
		}
	}
	return count;
}

// ---------------------------------------------------------------------------
// Snapshot at chapter end
// ---------------------------------------------------------------------------

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bSnapshotTaken = false;
	if (g_bHaveLast && g_cvAnnounce.BoolValue)
		CreateTimer(20.0, Timer_Announce, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_Announce(Handle timer)
{
	PrintToChatAll("\x04[Results]\x01 Type \x05!lastresults\x01 (or \x05!slr\x01) to see every survivor's stats from the last chapter.");
	return Plugin_Stop;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) { TakeSnapshot("completed"); }
void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)     { TakeSnapshot("finale won"); }
void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)   { TakeSnapshot("wiped"); }

void TakeSnapshot(const char[] outcome)
{
	if (g_bSnapshotTaken)
		return;
	g_bSnapshotTaken = true;

	g_iLastCount = CollectRows(g_sLastNames, g_iLastStats);
	GetCurrentMap(g_sLastMap, sizeof(g_sLastMap));
	strcopy(g_sLastOutcome, sizeof(g_sLastOutcome), outcome);
	g_bHaveLast = g_iLastCount > 0;
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

Action Cmd_LastResults(int client, int args)
{
	if (!g_bHaveLast)
	{
		ReplyToCommand(client, "[Results] No previous chapter recorded yet.");
		return Plugin_Handled;
	}

	char title[128];
	FormatEx(title, sizeof(title), "Last chapter: %s (%s)", g_sLastMap, g_sLastOutcome);
	ShowResults(client, title, g_sLastNames, g_iLastStats, g_iLastCount);
	return Plugin_Handled;
}

Action Cmd_Results(int client, int args)
{
	char names[MAX_ROWS][MAX_NAME_LENGTH];
	int stats[MAX_ROWS][ST_COUNT];
	int count = CollectRows(names, stats);

	char map[64], title[128];
	GetCurrentMap(map, sizeof(map));
	FormatEx(title, sizeof(title), "This chapter so far: %s", map);
	ShowResults(client, title, names, stats, count);
	return Plugin_Handled;
}

void ShowResults(int client, const char[] title, char names[MAX_ROWS][MAX_NAME_LENGTH], int stats[MAX_ROWS][ST_COUNT], int count)
{
	bool inGame = client > 0 && IsClientInGame(client);

	// Highlights, like the end-of-chapter screen but for every survivor: chat and console.
	if (inGame)
		PrintToChat(client, "\x04[Results]\x01 %s", title);
	PrintToConsoleOrServer(client, "==== %s ====", title);
	PrintToConsoleOrServer(client, "-- Highlights --");
	for (int h = 0; h < sizeof(g_Highlights); h++)
	{
		int best = FindBest(stats, count, g_Highlights[h].stat, g_Highlights[h].lowest);
		if (best == -1)
			continue;
		if (inGame)
			PrintToChat(client, "\x04%s:\x01 %s (%d)", g_Highlights[h].title, names[best], stats[best][g_Highlights[h].stat]);
		PrintToConsoleOrServer(client, "%s: %s (%d)", g_Highlights[h].title, names[best], stats[best][g_Highlights[h].stat]);
	}

	// One line per survivor in chat.
	if (inGame)
	{
		for (int r = 0; r < count; r++)
		{
			PrintToChat(client, "\x05%s\x01: %d common, %d special | tank dmg %d | witch dmg %d | friendly fire %d | taken %d | incaps %d | revives %d | heals %d",
				names[r], stats[r][ST_COMMON], stats[r][ST_SPECIAL], stats[r][ST_TANKDMG], stats[r][ST_WITCHDMG],
				stats[r][ST_FF], stats[r][ST_TAKEN], stats[r][ST_INCAP], stats[r][ST_REVIVE], stats[r][ST_HEAL]);
		}
		PrintToChat(client, "\x04[Results]\x01 Full table (kills by type, headshots, melee, deaths) is in your console (~).");
	}

	// Full table in the console (works from the server console too).
	PrintToConsoleOrServer(client, "-- All survivors --");
	PrintToConsoleOrServer(client, "%-20s %6s %7s %5s %6s %9s %5s %9s %10s %13s %12s %6s %6s %7s %5s",
		"Survivor", "Common", "Special", "Tanks", "Witches", "Headshots", "Melee", "Tank Dmg", "Witch Dmg",
		"Friendly Fire", "Damage Taken", "Incaps", "Deaths", "Revives", "Heals");
	for (int r = 0; r < count; r++)
	{
		PrintToConsoleOrServer(client, "%-20.20s %6d %7d %5d %6d %9d %5d %9d %10d %13d %12d %6d %6d %7d %5d", names[r],
			stats[r][ST_COMMON], stats[r][ST_SPECIAL], stats[r][ST_TANKKILLS], stats[r][ST_WITCHKILLS],
			stats[r][ST_HEADSHOT], stats[r][ST_MELEE], stats[r][ST_TANKDMG], stats[r][ST_WITCHDMG],
			stats[r][ST_FF], stats[r][ST_TAKEN], stats[r][ST_INCAP], stats[r][ST_DEATHS],
			stats[r][ST_REVIVE], stats[r][ST_HEAL]);
	}
}

// Row index of the survivor who wins a highlight, or -1 if nobody qualifies.
// "Most" highlights need a value above zero; "least" highlights need at least two survivors.
int FindBest(int stats[MAX_ROWS][ST_COUNT], int count, int stat, bool lowest)
{
	if (count == 0 || (lowest && count < 2))
		return -1;

	int best = 0;
	for (int r = 1; r < count; r++)
	{
		if (lowest ? stats[r][stat] < stats[best][stat] : stats[r][stat] > stats[best][stat])
			best = r;
	}

	if (!lowest && stats[best][stat] <= 0)
		return -1;
	return best;
}

void PrintToConsoleOrServer(int client, const char[] format, any ...)
{
	char buffer[320];
	VFormat(buffer, sizeof(buffer), format, 3);
	if (client > 0 && IsClientInGame(client))
		PrintToConsole(client, "%s", buffer);
	else
		PrintToServer("%s", buffer);
}
