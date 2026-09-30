/*
 * [L4D2] Vocalize Spam
 * L4D1 let voice lines be spammed. L4D2 ignores a new line while the survivor is still talking.
 * This plugin brings the spam back, in one of two ways (l4d2_vocalize_spam_stack):
 *
 *   stack 1: the new line plays ON TOP of the one still playing. The first line is a normal scene
 *            (mouth moves, subtitles); lines stacked on top of it are audio only.
 *   stack 0: the new line cuts off the one still playing (the survivor's instanced_scripted_scene
 *            is cancelled so the game accepts the new one).
 *
 * Lines the game triggers on its own ("vocalize smartlook auto", e.g. "Reloading!") are left alone.
 *
 * Key binds such as  bind v "vocalize PlayerLaugh"  also work: L4D2 ignores a vocalize command without
 * the menu's time token, so the plugin makes the survivor speak the line directly with the
 * SpeakResponseConcept input (l4d2_vocalize_spam_binds).
 *
 * Specific lines: sm_vline <line> plays one exact line of your character (bind v "sm_vline laughter12").
 * sm_vlines <word> lists your character's lines whose name or description contains <word>.
 *
 * Which lines exist is read from the game's talker scripts (scripts/talker/<character>.txt).
 * A scene "scenes/<character>/<name>.vcd" always has its audio at
 * "sound/player/survivor/voice/<character>/<name>.wav", which is what stacked lines play.
 * The character is taken from the survivor's model, so it matches the voice they have.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1.0"
#define TEAM_SURVIVOR  2
#define MAX_EDICTS     2048
#define NUM_CHARS      8
#define MAX_LIST_LINES 150

// Talker folder names, criteria names, and model file names, in the same order.
static const char g_sCharDirs[NUM_CHARS][]  = { "gambler", "producer", "coach", "mechanic", "namvet", "teengirl", "biker", "manager" };
static const char g_sCharCrit[NUM_CHARS][]  = { "IsGambler", "IsProducer", "IsCoach", "IsMechanic", "IsNamVet", "IsTeenGirl", "IsBiker", "IsManager" };
static const char g_sCharModel[NUM_CHARS][] = { "survivor_gambler", "survivor_producer", "survivor_coach", "survivor_mechanic", "survivor_namvet", "survivor_teenangst", "survivor_biker", "survivor_manager" };

ConVar g_cvEnabled;
ConVar g_cvInterval;
ConVar g_cvStack;
ConVar g_cvBinds;
ConVar g_cvDebug;

bool  g_bSceneStarted[MAX_EDICTS + 1];
float g_fLastVocalize[MAXPLAYERS + 1];
char  g_sLastLine[MAXPLAYERS + 1][64];

StringMap g_smResponses;  // response name (lower case) -> ArrayList of "char/name"
StringMap g_smBestResp;   // "concept|char" (lower case) -> response name of the most general rule
StringMap g_smBestCount;  // "concept|char" -> score of that rule (see StoreRule)
StringMap g_smLines;      // "char/name" -> description from the talker script comment

public Plugin myinfo =
{
	name        = "[L4D2] Vocalize Spam",
	author      = "forgotten893",
	description = "Spammable and stackable voice lines, like L4D1",
	version     = PLUGIN_VERSION,
	url         = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_vocalize_spam_version", PLUGIN_VERSION, "Vocalize Spam version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnabled  = CreateConVar("l4d2_vocalize_spam_enable", "1", "1 = voice lines can be spammed, 0 = off", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvInterval = CreateConVar("l4d2_vocalize_spam_interval", "0.1", "Minimum seconds between one player's voice lines (0 = no limit)", FCVAR_NOTIFY, true, 0.0);
	g_cvStack    = CreateConVar("l4d2_vocalize_spam_stack", "1", "1 = new lines play on top of the current one, 0 = new lines cut off the current one", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvBinds    = CreateConVar("l4d2_vocalize_spam_binds", "1", "1 = key binds / console \"vocalize <line>\" work (e.g. bind v \"vocalize PlayerLaugh\")", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDebug    = CreateConVar("l4d2_vocalize_spam_debug", "0", "1 = log vocalize commands and scene starts to the server console", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_vocalize_spam");

	RegConsoleCmd("sm_vline", Cmd_VLine, "sm_vline <line> - say one specific voice line, e.g. sm_vline laughter12");
	RegConsoleCmd("sm_vlines", Cmd_VLines, "sm_vlines <word> - list your character's voice lines containing <word>, e.g. sm_vlines laugh");

	AddCommandListener(OnVocalize, "vocalize");
	HookEntityOutput("instanced_scripted_scene", "OnStart", OnSceneStart);

	g_smResponses = new StringMap();
	g_smBestResp  = new StringMap();
	g_smBestCount = new StringMap();
	g_smLines     = new StringMap();
	LoadTalkerScripts();
}

public void OnClientDisconnect(int client)
{
	g_fLastVocalize[client] = 0.0;
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fLastVocalize[i] = 0.0;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && entity <= MAX_EDICTS)
	{
		g_bSceneStarted[entity] = false;
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity > 0 && entity <= MAX_EDICTS)
	{
		g_bSceneStarted[entity] = false;
	}
}

void OnSceneStart(const char[] output, int caller, int activator, float delay)
{
	if (caller <= 0 || caller > MAX_EDICTS)
	{
		return;
	}
	g_bSceneStarted[caller] = true;

	if (g_cvDebug.BoolValue)
	{
		char sFile[PLATFORM_MAX_PATH];
		GetEntPropString(caller, Prop_Data, "m_iszSceneFile", sFile, sizeof(sFile));
		int owner = GetEntPropEnt(caller, Prop_Data, "m_hOwner");
		PrintToServer("[VocalizeSpam] scene %d started, owner %d: %s", caller, owner, sFile);
	}
}

// ---------------------------------------------------------------------------------------------
// vocalize command (menu and key binds)
// ---------------------------------------------------------------------------------------------

Action OnVocalize(int client, const char[] command, int argc)
{
	if (!g_cvEnabled.BoolValue || !IsLiveHumanSurvivor(client) || argc < 1)
	{
		return Plugin_Continue;
	}

	char sConcept[64];
	GetCmdArg(1, sConcept, sizeof(sConcept));

	// "vocalize smartlook auto" is the game speaking for the player (not the menu). Leave it alone.
	if (argc >= 2)
	{
		char sArg2[64];
		GetCmdArg(2, sArg2, sizeof(sArg2));
		if (StrEqual(sArg2, "auto", false))
		{
			return Plugin_Continue;
		}
	}

	bool bBind = (argc == 1);
	if (bBind && !g_cvBinds.BoolValue)
	{
		return Plugin_Continue;
	}

	if (!PassesInterval(client))
	{
		return bBind ? Plugin_Handled : Plugin_Continue;
	}

	if (IsSpeaking(client))
	{
		if (g_cvStack.BoolValue)
		{
			char sLine[PLATFORM_MAX_PATH];
			if (PickConceptLine(client, sConcept, sLine, sizeof(sLine)))
			{
				EmitLineAudio(client, sLine);
				if (g_cvDebug.BoolValue)
				{
					PrintToServer("[VocalizeSpam] %N: %s stacked -> %s", client, sConcept, sLine);
				}
				return Plugin_Handled;
			}
			// Concept not in the talker data (e.g. smartlook): fall through and cut off instead.
		}
		CancelClientScenes(client);
	}

	if (bBind)
	{
		// No menu token, so the game would ignore the command. Play a line for the concept ourselves,
		// picked by the survivor's model so the voice always matches what they look like.
		char sLine[PLATFORM_MAX_PATH];
		if (PickConceptLine(client, sConcept, sLine, sizeof(sLine)))
		{
			PlayLineScene(client, sLine);
			if (g_cvDebug.BoolValue)
			{
				PrintToServer("[VocalizeSpam] %N: bind %s -> %s", client, sConcept, sLine);
			}
			return Plugin_Handled;
		}

		// Concept not in the talker data: let the game pick a line.
		SetVariantString(sConcept);
		AcceptEntityInput(client, "SpeakResponseConcept");
		if (g_cvDebug.BoolValue)
		{
			PrintToServer("[VocalizeSpam] %N: bind -> SpeakResponseConcept %s", client, sConcept);
		}
		return Plugin_Handled;
	}

	if (g_cvDebug.BoolValue)
	{
		PrintToServer("[VocalizeSpam] %N: menu vocalize %s", client, sConcept);
	}
	return Plugin_Continue;
}

// ---------------------------------------------------------------------------------------------
// sm_vline / sm_vlines
// ---------------------------------------------------------------------------------------------

Action Cmd_VLine(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[VocalizeSpam] This command is for players.");
		return Plugin_Handled;
	}
	if (args < 1)
	{
		ReplyToCommand(client, "[VocalizeSpam] Usage: sm_vline <line>, e.g. sm_vline laughter12. List lines with sm_vlines <word>.");
		return Plugin_Handled;
	}
	if (!g_cvEnabled.BoolValue || !IsLiveHumanSurvivor(client))
	{
		return Plugin_Handled;
	}

	int ch = GetClientChar(client);
	if (ch == -1)
	{
		ReplyToCommand(client, "[VocalizeSpam] Unknown survivor model.");
		return Plugin_Handled;
	}

	char sName[64], sLine[PLATFORM_MAX_PATH], sDesc[4];
	GetCmdArg(1, sName, sizeof(sName));
	ReplaceString(sName, sizeof(sName), ".vcd", "", false);
	String_ToLower(sName);
	FormatEx(sLine, sizeof(sLine), "%s/%s", g_sCharDirs[ch], sName);

	if (!g_smLines.GetString(sLine, sDesc, sizeof(sDesc)))
	{
		ReplyToCommand(client, "[VocalizeSpam] %s has no line \"%s\". Find lines with: sm_vlines <word>", g_sCharDirs[ch], sName);
		return Plugin_Handled;
	}

	if (!PassesInterval(client))
	{
		return Plugin_Handled;
	}

	if (IsSpeaking(client))
	{
		if (g_cvStack.BoolValue)
		{
			EmitLineAudio(client, sLine);
			return Plugin_Handled;
		}
		CancelClientScenes(client);
	}
	PlayLineScene(client, sLine);
	return Plugin_Handled;
}

Action Cmd_VLines(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	int ch = GetClientChar(client);
	if (ch == -1)
	{
		ReplyToCommand(client, "[VocalizeSpam] Unknown survivor model.");
		return Plugin_Handled;
	}

	char sFilter[64];
	if (args >= 1)
	{
		GetCmdArgString(sFilter, sizeof(sFilter));
		StripQuotes(sFilter);
		TrimString(sFilter);
	}
	if (!sFilter[0])
	{
		ReplyToCommand(client, "[VocalizeSpam] Usage: sm_vlines <word>, e.g. sm_vlines laugh (searches line names and descriptions).");
		return Plugin_Handled;
	}

	char sPrefix[32];
	FormatEx(sPrefix, sizeof(sPrefix), "%s/", g_sCharDirs[ch]);
	int prefixLen = strlen(sPrefix);

	ArrayList matches = new ArrayList(ByteCountToCells(64));
	StringMapSnapshot snap = g_smLines.Snapshot();
	char sKey[PLATFORM_MAX_PATH], sDesc[256];
	for (int i = 0; i < snap.Length; i++)
	{
		snap.GetKey(i, sKey, sizeof(sKey));
		if (strncmp(sKey, sPrefix, prefixLen) != 0)
		{
			continue;
		}
		g_smLines.GetString(sKey, sDesc, sizeof(sDesc));
		if (StrContains(sKey[prefixLen], sFilter, false) != -1 || StrContains(sDesc, sFilter, false) != -1)
		{
			matches.PushString(sKey[prefixLen]);
		}
	}
	delete snap;
	matches.Sort(Sort_Ascending, Sort_String);

	PrintToConsole(client, "--- %s lines matching \"%s\" (%d) - play one with: sm_vline <name> ---", g_sCharDirs[ch], sFilter, matches.Length);
	char sName[64];
	for (int i = 0; i < matches.Length && i < MAX_LIST_LINES; i++)
	{
		matches.GetString(i, sName, sizeof(sName));
		FormatEx(sKey, sizeof(sKey), "%s%s", sPrefix, sName);
		g_smLines.GetString(sKey, sDesc, sizeof(sDesc));
		PrintToConsole(client, "  %-32s %s", sName, sDesc);
	}
	if (matches.Length > MAX_LIST_LINES)
	{
		PrintToConsole(client, "  ... %d more, use a more specific word.", matches.Length - MAX_LIST_LINES);
	}
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintToChat(client, "[VocalizeSpam] %d line(s) listed in your console.", matches.Length);
	}
	delete matches;
	return Plugin_Handled;
}

// ---------------------------------------------------------------------------------------------
// Playing lines
// ---------------------------------------------------------------------------------------------

bool IsLiveHumanSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)
		&& GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client);
}

bool PassesInterval(int client)
{
	float now = GetEngineTime();
	float interval = g_cvInterval.FloatValue;
	if (interval > 0.0 && now - g_fLastVocalize[client] < interval)
	{
		return false;
	}
	g_fLastVocalize[client] = now;
	return true;
}

// Talker character index from the survivor's model, or -1.
int GetClientChar(int client)
{
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));
	for (int i = 0; i < NUM_CHARS; i++)
	{
		if (StrContains(sModel, g_sCharModel[i], false) != -1)
		{
			return i;
		}
	}
	return -1;
}

// True while the survivor has a scene (voice line) that is starting or playing.
bool IsSpeaking(int client)
{
	int scene = -1;
	while ((scene = FindEntityByClassname(scene, "instanced_scripted_scene")) != -1)
	{
		if (GetEntPropEnt(scene, Prop_Data, "m_hOwner") == client)
		{
			return true;
		}
	}
	return false;
}

// Stops every scene this survivor is the speaker of. Returns how many were stopped.
int CancelClientScenes(int client)
{
	int count = 0;
	int scene = -1;
	while ((scene = FindEntityByClassname(scene, "instanced_scripted_scene")) != -1)
	{
		if (GetEntPropEnt(scene, Prop_Data, "m_hOwner") != client)
		{
			continue;
		}

		// "Cancel" on a scene that has not started yet can crash the server, so remove those instead.
		if (scene <= MAX_EDICTS && g_bSceneStarted[scene])
		{
			AcceptEntityInput(scene, "Cancel");
		}
		else
		{
			RemoveEntity(scene);
		}
		count++;
	}
	return count;
}

// Picks a random line ("char/name") the survivor would say for a concept such as PlayerLaugh.
bool PickConceptLine(int client, const char[] sConcept, char[] sLine, int maxlen)
{
	int ch = GetClientChar(client);
	if (ch == -1)
	{
		return false;
	}

	char sKey[128], sResp[128];
	FormatEx(sKey, sizeof(sKey), "%s|%s", sConcept, g_sCharDirs[ch]);
	String_ToLower(sKey);
	if (!g_smBestResp.GetString(sKey, sResp, sizeof(sResp)))
	{
		return false;
	}

	ArrayList lines;
	if (!g_smResponses.GetValue(sResp, lines) || lines.Length == 0)
	{
		return false;
	}
	// Random line, but never the same one this player got last time (when there is a choice).
	int count = lines.Length;
	int pick = GetRandomInt(0, count - 1);
	lines.GetString(pick, sLine, maxlen);
	if (count > 1 && StrEqual(sLine, g_sLastLine[client]))
	{
		pick = (pick + GetRandomInt(1, count - 1)) % count;
		lines.GetString(pick, sLine, maxlen);
	}
	strcopy(g_sLastLine[client], sizeof(g_sLastLine[]), sLine);
	return true;
}

// Audio only, on an automatic channel, so it plays on top of whatever the survivor is saying.
void EmitLineAudio(int client, const char[] sLine)
{
	char sSound[PLATFORM_MAX_PATH];
	FormatEx(sSound, sizeof(sSound), "player/survivor/voice/%s.wav", sLine);
	PrecacheSound(sSound);
	EmitSoundToAll(sSound, client, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
}

// A real scene (mouth movement, subtitles), used when the survivor is not already talking.
void PlayLineScene(int client, const char[] sLine)
{
	char sScene[PLATFORM_MAX_PATH];
	FormatEx(sScene, sizeof(sScene), "scenes/%s.vcd", sLine);

	int scene = CreateEntityByName("instanced_scripted_scene");
	if (scene == -1)
	{
		return;
	}
	DispatchKeyValue(scene, "SceneFile", sScene);
	SetEntPropEnt(scene, Prop_Data, "m_hOwner", client);
	DispatchSpawn(scene);
	ActivateEntity(scene);
	AcceptEntityInput(scene, "Start", client, client);
}

// ---------------------------------------------------------------------------------------------
// Talker script parsing
// ---------------------------------------------------------------------------------------------

static const char g_sTalkerSuffixes[][] = { "", "_dlc1", "_dlc2", "_dlc3" };
int g_iTalkerFilesRead;

// One file per frame, so a big file can't hit SourceMod's script timeout.
void LoadTalkerScripts()
{
	g_iTalkerFilesRead = 0;
	RequestFrame(LoadTalkerFile, 0);
}

void LoadTalkerFile(int index)
{
	int total = NUM_CHARS * sizeof(g_sTalkerSuffixes);
	if (index >= total)
	{
		LogMessage("Read %d talker files: %d responses, %d lines, %d concept/character pairs.",
			g_iTalkerFilesRead, g_smResponses.Size, g_smLines.Size, g_smBestResp.Size);
		return;
	}

	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "scripts/talker/%s%s.txt",
		g_sCharDirs[index / sizeof(g_sTalkerSuffixes)], g_sTalkerSuffixes[index % sizeof(g_sTalkerSuffixes)]);
	float start = GetEngineTime();
	// The main file (<char>.txt) is the current one; the _dlc files hold older copies of some rules.
	int lines = ParseTalkerFile(sPath, (index % sizeof(g_sTalkerSuffixes)) == 0 ? 0 : 1);
	if (lines >= 0)
	{
		g_iTalkerFilesRead++;
		if (g_cvDebug.BoolValue)
		{
			LogMessage("%s: %d lines in %.2f s", sPath, lines, GetEngineTime() - start);
		}
	}
	RequestFrame(LoadTalkerFile, index + 1);
}

// Returns the number of lines read, or -1 if the file does not exist.
int ParseTalkerFile(const char[] sPath, int priority)
{
	File file = OpenFile(sPath, "r", true);
	if (file == null)
	{
		return -1;
	}

	char sLine[1024], sWord[128];
	char sBlockName[128];
	char sRuleCriteria[1024], sRuleResponse[128];
	int blockType = 0; // 0 none, 1 response, 2 rule
	ArrayList currentLines = null;

	int count = 0;
	while (count < 200000 && !file.EndOfFile() && file.ReadLine(sLine, sizeof(sLine)))
	{
		count++;
		TrimString(sLine);
		if (!sLine[0] || (sLine[0] == '/' && sLine[1] == '/'))
		{
			continue;
		}

		int next = BreakString(sLine, sWord, sizeof(sWord));

		if (StrEqual(sWord, "Response", false) && blockType != 2)
		{
			if (next == -1)
			{
				continue;
			}
			BreakString(sLine[next], sBlockName, sizeof(sBlockName));
			String_ToLower(sBlockName);
			blockType = 1;
			currentLines = null;
			if (!g_smResponses.GetValue(sBlockName, currentLines))
			{
				currentLines = new ArrayList(ByteCountToCells(64));
				g_smResponses.SetValue(sBlockName, currentLines);
			}
			else
			{
				currentLines = null; // already read from a file earlier in the search order
			}
		}
		else if (StrEqual(sWord, "Rule", false))
		{
			blockType = 2;
			sRuleCriteria[0] = '\0';
			sRuleResponse[0] = '\0';
		}
		else if (sLine[0] == '}')
		{
			if (blockType == 2)
			{
				StoreRule(sRuleCriteria, sRuleResponse, priority);
			}
			blockType = 0;
			currentLines = null;
		}
		else if (blockType == 1 && StrEqual(sWord, "scene", false) && next != -1)
		{
			AddResponseScene(currentLines, sLine[next]);
		}
		else if (blockType == 2 && StrEqual(sWord, "criteria", false) && next != -1)
		{
			strcopy(sRuleCriteria, sizeof(sRuleCriteria), sLine[next]);
		}
		else if (blockType == 2 && StrEqual(sWord, "Response", false) && next != -1)
		{
			BreakString(sLine[next], sRuleResponse, sizeof(sRuleResponse));
			String_ToLower(sRuleResponse);
		}
	}
	delete file;
	return count;
}

// sRest is e.g.:  "scenes/Gambler/Laughter01.vcd"  //<Hearty Laugh>
void AddResponseScene(ArrayList lines, const char[] sRest)
{
	char sScene[PLATFORM_MAX_PATH];
	BreakString(sRest, sScene, sizeof(sScene));
	String_ToLower(sScene);
	if (strncmp(sScene, "scenes/", 7) != 0)
	{
		return;
	}
	int ext = StrContains(sScene, ".vcd");
	if (ext == -1)
	{
		return;
	}
	sScene[ext] = '\0';

	// Only survivor folders: "scenes/<char>/<name>"
	char sLine[PLATFORM_MAX_PATH];
	strcopy(sLine, sizeof(sLine), sScene[7]);
	bool survivor = false;
	for (int i = 0; i < NUM_CHARS; i++)
	{
		int len = strlen(g_sCharDirs[i]);
		if (strncmp(sLine, g_sCharDirs[i], len) == 0 && sLine[len] == '/')
		{
			survivor = true;
			break;
		}
	}
	if (!survivor)
	{
		return;
	}

	char sDesc[256];
	int comment = StrContains(sRest, "//");
	if (comment != -1)
	{
		strcopy(sDesc, sizeof(sDesc), sRest[comment + 2]);
		TrimString(sDesc);
	}

	char sOld[4];
	if (!g_smLines.GetString(sLine, sOld, sizeof(sOld)) || sDesc[0])
	{
		g_smLines.SetString(sLine, sDesc);
	}
	if (lines != null)
	{
		lines.PushString(sLine);
	}
}

// Keeps, per concept and character, the rule with the fewest criteria: that is the general one
// (e.g. PlayerThanksGambler), not a special case like thanking a specific survivor.
// Rules from the main file always beat rules from the _dlc files (priority 0 beats 1), because the
// _dlc files contain outdated copies (e.g. Bill's PlayerLaugh there has 2 laughs instead of 6).
void StoreRule(const char[] sCriteria, const char[] sResponse, int priority)
{
	if (!sCriteria[0] || !sResponse[0])
	{
		return;
	}

	char sWord[128], sConcept[64];
	int ch = -1, count = 0, pos = 0, next;
	sConcept[0] = '\0';
	while (pos != -1 && sCriteria[pos])
	{
		next = BreakString(sCriteria[pos], sWord, sizeof(sWord));
		if (sWord[0])
		{
			count++;
			if (strncmp(sWord, "Concept", 7, false) == 0 && !sConcept[0])
			{
				strcopy(sConcept, sizeof(sConcept), sWord[7]);
			}
			for (int i = 0; i < NUM_CHARS; i++)
			{
				if (StrEqual(sWord, g_sCharCrit[i], false))
				{
					ch = i;
				}
			}
		}
		pos = (next == -1) ? -1 : pos + next;
	}
	if (ch == -1 || !sConcept[0])
	{
		return;
	}

	char sKey[128];
	FormatEx(sKey, sizeof(sKey), "%s|%s", sConcept, g_sCharDirs[ch]);
	String_ToLower(sKey);
	int score = priority * 1000 + count;
	int oldScore;
	if (g_smBestCount.GetValue(sKey, oldScore) && oldScore <= score)
	{
		return;
	}
	g_smBestCount.SetValue(sKey, score);
	g_smBestResp.SetString(sKey, sResponse);
}

void String_ToLower(char[] str)
{
	for (int i = 0; str[i]; i++)
	{
		str[i] = CharToLower(str[i]);
	}
}
