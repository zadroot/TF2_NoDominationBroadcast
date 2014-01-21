/**
* No Domination Broadcast by Root
*
* Description:
*   Disables "Domination & Revenge" features in Team Fortress 2.
*
* Version 1.2.3
* Changelog & more info at http://goo.gl/4nKhJ
*/

// ====[ INCLUDES ]==================================================
#include <tf2_stocks> // <tf2_stocks> is automatically includes <sdktools> and <tf2>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

// ====[ CONSTANTS ]=================================================
#define PLUGIN_NAME    "No Domination Broadcast"
#define PLUGIN_VERSION "1.2.3"
#define UPDATE_URL     "https://raw.github.com/zadroot/TF2_NoDominationBroadcast/master/updater.txt"

// ====[ VARIABLES ]=================================================
new	Handle:nobroadcast = INVALID_HANDLE,
	m_bPlayerDominated, m_bPlayerDominatingMe, m_iActiveDominations, // NetProps
	zeroCount[MAXPLAYERS + 1];

// ====[ PLUGIN ]====================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Disables Domination & Revenge broadcasting",
	version     = PLUGIN_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=1807594"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ------------------------------------------------------------------ */
public OnPluginStart()
{
	// Create console variables
	CreateConVar("sm_nodominations_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	nobroadcast = CreateConVar("sm_nodominations", "1", "Disable Domination & Revenge broadcasting?", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	// Always use pre hook mode if you want to block or rewrite an event
	HookEvent("player_death",     OnPlayerDeath, EventHookMode_Pre);
	HookConVarChange(nobroadcast, OnConVarChange);

	// Find the Dominations/Revenge netprops
	m_bPlayerDominated    = FindSendPropInfoEx("CTFPlayer",         "m_bPlayerDominated");
	m_bPlayerDominatingMe = FindSendPropInfoEx("CTFPlayer",         "m_bPlayerDominatingMe");
	m_iActiveDominations  = FindSendPropInfoEx("CTFPlayerResource", "m_iActiveDominations");

#if defined _updater_included
	if (LibraryExists("updater"))
	{
		// Add plugin to the updater
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}
#if defined _updater_included
/* OnLibraryAdded()
 *
 * Called after a library is added that the current plugin references.
 * ------------------------------------------------------------------ */
public OnLibraryAdded(const String:name[])
{
	// Make sure the 'updater' library were added
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}
#endif
/* OnMapStart()
 *
 * Called when the map has loaded and all plugin configs are done executing.
 * ------------------------------------------------------------------ */
public OnConfigsExecuted()
{
	// Plugin is enabled?
	if (GetConVarBool(nobroadcast))
	{
		// Make sure we can hook PlayerResourceEntity
		if (!SDKHookEx(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnResourceThink))
		{
			SetFailState("Unable to hook resource entity!");
		}
	}
}

/* OnConVarChange()
 *
 * Called when a convar's value is changed.
 * ------------------------------------------------------------------ */
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Changed since SM 1.5
	new entity = GetPlayerResourceEntity();

	// Get changed value
	switch (StringToInt(newValue))
	{
		case false: // Unhook all features main convar value was changed to 0
		{
			SDKUnhook(entity, SDKHook_ThinkPost, OnResourceThink);
			UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
		}
		case true: // Otherwise hook everything back
		{
			SDKHook(entity, SDKHook_ThinkPost, OnResourceThink);
			HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
		}
	}
}

/* OnPlayerDeath()
 *
 * Called when a player dies.
 * ------------------------------------------------------------------ */
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Getting attacker's user ID (who killed) and victim's user ID (who died)
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));

	// Way to get dominations and revenges is death_flags
	new death_flags = GetEventInt(event, "death_flags");

	// Thanks to FaTony for this
	death_flags &= ~(TF_DEATHFLAG_KILLERDOMINATION | TF_DEATHFLAG_ASSISTERDOMINATION | TF_DEATHFLAG_KILLERREVENGE | TF_DEATHFLAG_ASSISTERREVENGE);

	// Sets the integer value of a game event's key
	SetEventInt(event, "death_flags", death_flags);

	// Disable domination features
	SetNetProps(attacker, victim);
}

/* OnThinkPost()
 *
 * A SDKHooks 'after think' feature.
 * ------------------------------------------------------------------ */
public OnResourceThink(entity)
{
	// Copies an array of cells to an entity at a dominations offset
	SetEntDataArray(entity, m_iActiveDominations, zeroCount, MaxClients+1);
}

/* SetNetProps()
 *
 * Sets net properites for dominations and revenges.
 * ------------------------------------------------------------------ */
SetNetProps(attacker, victim)
{
	// Make sure attacker is valid
	if (attacker && IsClientInGame(attacker))
	{
		// First remove 'DOMINATED' icon in a scoreboard
		SetEntData(attacker, m_bPlayerDominated + victim, false, 4, true);
	}

	// And victim
	if (victim && IsClientInGame(victim))
	{
		// Then remove 'NEMESIS' icon in a scoreboard
		SetEntData(victim, m_bPlayerDominatingMe + attacker, false, 4, true);
	}
}

/* FindSendPropInfoEx()
 *
 * Returns the offset of the specified network property.
 * ------------------------------------------------------------------ */
FindSendPropInfoEx(const String:serverClass[64], const String:propName[64])
{
	new info = FindSendPropInfo(serverClass, propName);

	// Disable plugin if a networkable send property offset was not found
	if (info <= 0)
	{
		SetFailState("Unable to find offs \"%s::%s\"!", serverClass, propName);
	}

	return info;
}