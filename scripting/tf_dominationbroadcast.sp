/**
* No Domination Broadcast by Root
*
* Description:
*   Disables "Domination & Revenge" features in Team Fortress 2.
*
* Version 1.2
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1 // Force strict semicolon mode.

// ====[ INCLUDES ]===================================================
#include <sourcemod>
#include <tf2_stocks> // <tf2_stocks> is automatically includes sdktools.inc and tf2.inc
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <updater>

// ====[ CONSTANTS ]==================================================
#define PLUGIN_VERSION "1.2"
#define UPDATE_URL	   "https://freefhost.googlecode.com/svn/root/dombroadcast.txt"

// ====[ VARIABLES ]==================================================
new Handle:dombroadcast = INVALID_HANDLE;
new m_bPlayerDominated, m_bPlayerDominatingMe, m_iActiveDominations; // NetProps
new zeroCount[MAXPLAYERS + 1];

// ====[ PLUGIN ]=====================================================
public Plugin:myinfo =
{
	name        = "No Domination Broadcast",
	author      = "Root",
	description = "Disables Domination & Revenge broadcasting",
	version     = PLUGIN_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=1807594"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * -------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create console variables
	CreateConVar("sm_nodominations_version", PLUGIN_VERSION, NULL_STRING, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);
	dombroadcast = CreateConVar("sm_nodominations", "1", "Enable or disable Domination & Revenge broadcasting.", FCVAR_PLUGIN|FCVAR_SPONLY, true, 0.0, true, 1.0);

	// Always use hook event 'Pre' if want to block or rewrite an event
	HookEvent("player_death",      OnPlayerDeath, EventHookMode_Pre);
	HookConVarChange(dombroadcast, OnConVarChange);

	// Find the netprops
	m_bPlayerDominated    = GetSendPropInfo("CTFPlayer", "m_bPlayerDominated");
	m_bPlayerDominatingMe = GetSendPropInfo("CTFPlayer", "m_bPlayerDominatingMe");
	m_iActiveDominations  = GetSendPropInfo("CTFPlayerResource", "m_iActiveDominations");

	// Updater
	if (LibraryExists("updater"))
	{
		// Adds plugin to the updater
		Updater_AddPlugin(UPDATE_URL);
	}
}

/* OnLibraryAdded()
 *
 * Called after a library is added that the current plugin references optionally.
 * -------------------------------------------------------------------- */
public OnLibraryAdded(const String:name[])
{
	// Check for 'updater' library
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

/* OnMapStart()
 *
 * When the map starts.
 * -------------------------------------------------------------------- */
public OnMapStart()
{
	// Retrieves the entity index of the CTFPlayerResource entity
	new entity = FindEntityByClassname(-1, "tf_player_manager");

	// If resource entity is valid, hook it
	if (entity != -1)
	{
		SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
	}

	// Stop plugin if TFResource is not avalible
	else
	{
		SetFailState("Unable to find entity: \"tf_player_manager\"!");
	}
}

/* OnConVarChange()
 *
 * Called when a convar's value is changed.
 * -------------------------------------------------------------------- */
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Compare old and new convar values when changed
	if (strcmp(oldValue, newValue) != 0)
	{
		// Look at tf2.inc for this
		new entity = TF2_GetResourceEntity();

		// Unhook all features if convar value changed to 1
		if (strcmp(newValue, "0") == 0)
		{
			SDKUnhook(entity, SDKHook_ThinkPost, OnThinkPost);
			UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
		}

		// If changed to 0, hook everything back
		else
		{
			SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
			HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
		}
	}
}

/* OnPlayerDeath()
 *
 * Called when a player dies.
 * -------------------------------------------------------------------- */
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Getting attacker's user ID (who killed) and victim's user ID (who died)
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));

	// Way to get dominations and revenges is death_flags
	new death_flags = GetEventInt(event, "death_flags");

	// Thanks to FaTony for this!
	death_flags &= ~(TF_DEATHFLAG_KILLERDOMINATION | TF_DEATHFLAG_ASSISTERDOMINATION | TF_DEATHFLAG_KILLERREVENGE | TF_DEATHFLAG_ASSISTERREVENGE);

	// Sets the integer value of a game event's key
	SetEventInt(event, "death_flags", death_flags);

	// Disable domination features
	SetNetProps(attacker, victim);
}

/* OnThinkPost()
 *
 * A SDKHooks 'after think' feature.
 * -------------------------------------------------------------------- */
public OnThinkPost(entity)
{
	// Copies an array of cells to an entity at a dominations offset
	SetEntDataArray(entity, m_iActiveDominations, zeroCount, MaxClients + 1);
}

/* SetNetProps()
 *
 * Sets net properites/resource entity for dominations and revenges.
 * -------------------------------------------------------------------- */
SetNetProps(attacker, victim)
{
	// Make sure attacker is valid
	if (attacker > 0 && IsClientInGame(attacker))
	{
		// First remove 'DOMINATED' icon in a scoreboard
		SetEntData(attacker, m_bPlayerDominated + victim, 0, 4, true);
	}

	// And victim
	if (victim > 0 && IsClientInGame(victim))
	{
		// Then remove 'NEMESIS' icon in a scoreboard
		SetEntData(victim, m_bPlayerDominatingMe + attacker, 0, 4, true);
	}
}

/* GetSendPropInfo()
 *
 * Returns the offset of the specified network property.
 * -------------------------------------------------------------------- */
GetSendPropInfo(const String:serverClass[64], const String:propName[64])
{
	new entity = FindSendPropInfo(serverClass, propName);

	// Log an error and disable plugin if a networkable send property offset was not found
	if (!entity)
	{
		SetFailState("Fatal Error: Unable to find prop offset: \"%s:%s\"!", serverClass, propName);
	}

	// Return value
	return entity;
}