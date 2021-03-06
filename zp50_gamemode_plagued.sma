/*================================================================================
	
	------------------------------
	-*- [ZP] Game Mode: darkday -*-
	------------------------------ 
	
	This plugin is part of Zombie darkday Mod and is distributed under the
	terms of the GNU General Public License. Check ZP_ReadMe.txt for details.
	
================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <amx_settings_api>
#include <cs_teams_api>
#include <zp50_gamemodes>
#include <zp50_class_assassin>
#include <zp50_class_sniper>
#include <zp50_deathmatch>

// Settings file
new const ZP_SETTINGS_FILE[] = "zombieplague.ini"

// Default sounds
new const sound_darkday[][] = { "zombie_plague/zm_assassin_start.wav" , "zombie_plague/zm_assassin_start_2.wav" , "zombie_plague/zm_assassin_start_3.wav" }

#define SOUND_MAX_LENGTH 64

new Array:g_sound_darkday

// HUD messages
#define HUD_EVENT_X -1.0
#define HUD_EVENT_Y 0.17
#define HUD_EVENT_R 0
#define HUD_EVENT_G 50
#define HUD_EVENT_B 200

new g_MaxPlayers
new g_HudSync

new cvar_darkday_chance, cvar_darkday_min_players
new cvar_darkday_ratio
new cvar_darkday_assassin_count, cvar_darkday_assassin_hp_multi
new cvar_darkday_sniper_count, cvar_darkday_sniper_hp_multi
new cvar_darkday_show_hud, cvar_darkday_sounds
new cvar_darkday_allow_respawn

new g_msgScreenShake
new g_msgScreenFade
const FFADE_IN = 0x0000
const UNIT_SECOND = (1<<12)
new g_LValue[2]

public plugin_precache()
{
	// Register game mode at precache (plugin gets paused after this)
	register_plugin("[ZP] Game Mode: Dark Plague Mode", ZP_VERSION_STRING, "ZP Dev Team")
	zp_gamemodes_register("Dark Day Mode")
	
	// Create the HUD Sync Objects
	g_HudSync = CreateHudSyncObj()
	
	g_MaxPlayers = get_maxplayers()
	
	g_msgScreenShake = get_user_msgid("ScreenShake")
	g_msgScreenFade = get_user_msgid("ScreenFade")
	
	cvar_darkday_chance = register_cvar("zp_darkday_chance", "25")
	cvar_darkday_min_players = register_cvar("zp_darkday_min_players", "0")
	cvar_darkday_ratio = register_cvar("zp_darkday_ratio", "0.5")
	cvar_darkday_assassin_count = register_cvar("zp_darkday_assassin_count", "1")
	cvar_darkday_assassin_hp_multi = register_cvar("zp_darkday_assassin_hp_multi", "0.5")
	cvar_darkday_sniper_count = register_cvar("zp_darkday_sniper_count", "1")
	cvar_darkday_sniper_hp_multi = register_cvar("zp_darkday_sniper_hp_multi", "0.5")
	cvar_darkday_show_hud = register_cvar("zp_darkday_show_hud", "1")
	cvar_darkday_sounds = register_cvar("zp_darkday_sounds", "1")
	cvar_darkday_allow_respawn = register_cvar("zp_darkday_allow_respawn", "0")
	
	// Initialize arrays
	g_sound_darkday = ArrayCreate(SOUND_MAX_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZP_SETTINGS_FILE, "Sounds", "ROUND DARK DAY", g_sound_darkday)
	
	// If we couldn't load custom sounds from file, use and save default ones
	new index
	if (ArraySize(g_sound_darkday) == 0)
	{
		for (index = 0; index < sizeof sound_darkday; index++)
			ArrayPushString(g_sound_darkday, sound_darkday[index])
		
		// Save to external file
		amx_save_setting_string_arr(ZP_SETTINGS_FILE, "Sounds", "ROUND DARK DAY", g_sound_darkday)
	}
	
	// Precache sounds
	new sound[SOUND_MAX_LENGTH]
	for (index = 0; index < ArraySize(g_sound_darkday); index++)
	{
		ArrayGetString(g_sound_darkday, index, sound, charsmax(sound))
		if (equal(sound[strlen(sound)-4], ".mp3"))
		{
			format(sound, charsmax(sound), "sound/%s", sound)
			precache_generic(sound)
		}
		else
			precache_sound(sound)
	}
}

// Deathmatch module's player respawn forward
public zp_fw_deathmatch_respawn_pre(id)
{
	// Respawning allowed?
	if (!get_pcvar_num(cvar_darkday_allow_respawn))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public zp_fw_gamemodes_choose_pre(game_mode_id, skipchecks)
{
	new alive_count = GetAliveCount()
	
	if (!skipchecks)
	{
		// Random chance
		if (random_num(1, get_pcvar_num(cvar_darkday_chance)) != 1)
			return PLUGIN_HANDLED;
		
		// Min players
		if (alive_count < get_pcvar_num(cvar_darkday_min_players))
			return PLUGIN_HANDLED;
	}
	
	// There should be enough players to have the desired amount of assassin and snipers
	if (alive_count < get_pcvar_num(cvar_darkday_assassin_count) + get_pcvar_num(cvar_darkday_sniper_count))
		return PLUGIN_HANDLED;
	
	// Game mode allowed
	return PLUGIN_CONTINUE;
}

public zp_fw_gamemodes_start()
{
	// Calculate player counts
	new id, alive_count = GetAliveCount()
	new sniper_count = get_pcvar_num(cvar_darkday_sniper_count)
	new assassin_count = get_pcvar_num(cvar_darkday_assassin_count)
	new zombie_count = floatround((alive_count - (assassin_count + sniper_count)) * get_pcvar_float(cvar_darkday_ratio), floatround_ceil)
	
	// Turn specified amount of players into snipers
	new isnipers, iMaxsnipers = sniper_count
	while (isnipers < iMaxsnipers)
	{
		// Choose random guy
		id = GetRandomAlive(random_num(1, alive_count))
		
		// Already a sniper?
		if (zp_class_sniper_get(id))
			continue;
		
		// If not, turn him into one
		zp_class_sniper_set(id)
		isnipers++
		
		// Apply sniper health multiplier
		set_user_health(id, floatround(get_user_health(id) * get_pcvar_float(cvar_darkday_sniper_hp_multi)))
	}
	
	// Turn specified amount of players into assassin
	new iassassin, iMaxassassin = assassin_count
	while (iassassin < iMaxassassin)
	{
		// Choose random guy
		id = GetRandomAlive(random_num(1, alive_count))
		
		// Already a sniper or assassin?
		if (zp_class_sniper_get(id) || zp_class_assassin_get(id))
			continue;
		
		// If not, turn him into one
		zp_class_assassin_set(id)
		iassassin++
		
		// Apply assassin health multiplier
		set_user_health(id, floatround(get_user_health(id) * get_pcvar_float(cvar_darkday_assassin_hp_multi)))
	}
	
	// Randomly turn iMaxZombies players into zombies
	new iZombies, iMaxZombies = zombie_count
	while (iZombies < iMaxZombies)
	{
		// Choose random guy
		id = GetRandomAlive(random_num(1, alive_count))
		
		// Already a zombie/assassin or sniper
		if (zp_class_sniper_get(id) || zp_core_is_zombie(id))
			continue;
		
		// Turn into a zombie
		zp_core_infect(id, 0)
		iZombies++
	}
	
	// Turn the remaining players into humans
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		// Not alive
		if (!is_user_alive(id))
			continue;
		
		// Only those who aren't zombies/assassin or snipers
		if (zp_class_sniper_get(id) || zp_core_is_zombie(id))
			continue;
		
		// Switch to CT
		cs_set_player_team(id, CS_TEAM_CT)
		
		// Make a screen fade 
		message_begin(MSG_ONE, g_msgScreenFade, _, id)
		write_short(UNIT_SECOND*5) // duration
		write_short(0) // hold time
		write_short(FFADE_IN) // fade type
		write_byte(250) // red
		write_byte(0) // green
		write_byte(0) // blue
		write_byte(255) // alpha
		message_end()
			
		// Make a screen shake [Make it horrorful]
		message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, id)
		write_short(UNIT_SECOND*75) // amplitude
		write_short(UNIT_SECOND*7) // duration
		write_short(UNIT_SECOND*75) // frequency
		message_end()
	}
	
	// Play darkday sound
	if (get_pcvar_num(cvar_darkday_sounds))
	{
		new sound[SOUND_MAX_LENGTH]
		ArrayGetString(g_sound_darkday, random_num(0, ArraySize(g_sound_darkday) - 1), sound, charsmax(sound))
		PlaySoundToClients(sound) 
	}
	
	if (get_pcvar_num(cvar_darkday_show_hud))
	{
		// Show darkday HUD notice
		set_hudmessage(HUD_EVENT_R, HUD_EVENT_G, HUD_EVENT_B, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0, 5.0, 1.0, 1.0, -1)
		ShowSyncHudMsg(0, g_HudSync, "%L", LANG_PLAYER, "NOTICE_darkday")
	}
	
	// Setting Dark Lightning For The Mode
	get_cvar_string ( "zp_lighting", g_LValue , 2 )
	if ( !equali( "g_LValue" , "a" ) )
	{

		set_cvar_string ( "zp_lighting" , "a" )

	}
}

// Plays a sound on clients
PlaySoundToClients(const sound[])
{
	if (equal(sound[strlen(sound)-4], ".mp3"))
		client_cmd(0, "mp3 play ^"sound/%s^"", sound)
	else
		client_cmd(0, "spk ^"%s^"", sound)
}

// Get Alive Count -returns alive players number-
GetAliveCount()
{
	new iAlive, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
	}
	
	return iAlive;
}

// Get Random Alive -returns index of alive player number target_index -
GetRandomAlive(target_index)
{
	new iAlive, id
	
	for (id = 1; id <= g_MaxPlayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
		
		if (iAlive == target_index)
			return id;
	}
	
	return -1;
}

public zp_fw_gamemodes_end()
{
	// Setting The lighting Settings as before the Mode.
	new cfgdir[32]
	get_configsdir(cfgdir, charsmax(cfgdir))

	server_cmd("exec %s/zombieplague.cfg", cfgdir)
}