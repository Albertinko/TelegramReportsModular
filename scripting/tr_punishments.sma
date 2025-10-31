////////////////////////////////    HEADER    ////////////////////////////////

#include <amxmodx>
#include <tr_api>

#define PLUGIN_NAME	"Telegram Reports: Punishments"

////////////////////////////////    CONSTANTS    ////////////////////////////////

// The path to the configuration file
#define CFG_FILE	"addons/amxmodx/configs/tr_configs/tr_punishments.ini"

////////////////////////////////    GLOBAL VARIABLES    ////////////////////////////////

enum Sections {
	SECTION_NONE = -1,
	SECTION_SETTINGS
};

new Sections:ParserCurSection;

enum _:Settings {
	SEND_PHOTO,
	PHOTO_URL[MAX_URL_LENGTH]
};

new PluginSettings[Settings];

enum _:HostData {
	NAME[64],
	MAPNAME[64]
};

new Host[HostData];

////////////////////////////////    CONFIGURATION    ////////////////////////////////

// Fresh Bans
forward fbans_player_banned_pre_f(
	const id,
	const uid,
	const player_steamid[],
	const player_ip[],
	const player_name[],
	const admin_ip[],
	const admin_steamid[],
	const admin_name[],
	const ban_type[],
	const ban_reason[],
	const bantime
);

// [fork] Lite Bans
#define LB_MAX_REASON_LENGTH 96

forward user_banned_pre(
	banned_id,
	admin_id,
	ban_minutes,
	const ban_reason[LB_MAX_REASON_LENGTH]
);

// AMXBans RBS
forward amxbans_ban_pre(id, admin, bantime, bantype[], banreason[]);

// Chat Additions: Gag
forward CA_gag_setted(
	const target,
	name[],
	authID[],
	IP[],
	adminName[],
	adminAuthID[],
	adminIP[],
	reason[],
	time,
	gag_flags_s:flags,
	expireAt
);

// Ultimate GAG
forward gag_gaged(id, player, flags, unixtime, reason[]);

// GameCMS GagManager
#define GM_MAX_REASON_LENGTH 100

enum _:BlockInfo {
	GBid,
	GBlockType,
	GExpired,
	GAdminId,
	GCreated,
	GBlockTime,
	GAuthId[MAX_AUTHID_LENGTH],
	GName[MAX_NAME_LENGTH],
	GBlockReason[GM_MAX_REASON_LENGTH],
	GAdminNick[MAX_NAME_LENGTH],
	GModifiedBy[MAX_NAME_LENGTH],
	bool:GModifiedBlocked,
	GTargetID
};

enum _:eBlockFunc {
	BLOCK_FUNC_ADD = 1,
	BLOCK_FUNC_CHANGE,
	BLOCK_FUNC_REMOVE
};

forward OnCMSGagUserBlockAction(const id, eBlockFunc:iFunc, szData[BlockInfo]);

public plugin_precache() {
	if(!is_core_loaded())
		return;

	get_mapname(Host[MAPNAME], charsmax(Host[MAPNAME]));
	bind_pcvar_string(get_cvar_pointer("hostname"), Host[NAME], charsmax(Host[NAME]));

	ParseConfig();
}

public ParseConfig() {
	new INIParser:parser = INI_CreateParser();
	INI_SetReaders(parser, "ReadKeyValue", "ReadNewSection");
	INI_ParseFile(parser, CFG_FILE);
	INI_DestroyParser(parser);
}

public bool:ReadNewSection(INIParser:parser, const section[], bool:invalidTokens, bool:closeBracket) {	
	if(!closeBracket) {
		log_amx("Closing bracket was not detected! Current section name '%s'.", section);
		return false;
	}

	if(equal(section, "settings")) {
		ParserCurSection = SECTION_SETTINGS;
		return true;
	}

	return false;
}

public bool:ReadKeyValue(INIParser:parser, const key[], const value[]) {
	switch(ParserCurSection) {
		case SECTION_NONE: {
			return false;
		}
		case SECTION_SETTINGS: {
			if(equal(key, "SEND_PHOTO")) {
				PluginSettings[SEND_PHOTO] = str_to_num(value);
			} else if(equal(key, "PHOTO_URL")) {
				if(value[0] != EOS) {
					formatex(PluginSettings[PHOTO_URL], charsmax(PluginSettings[PHOTO_URL]), value);
				} else {
					formatex(PluginSettings[PHOTO_URL], charsmax(PluginSettings[PHOTO_URL]),
					"https://image.gametracker.com/images/maps/160x120/cs/%s.jpg", Host[MAPNAME]);
				}
			}
		}
	}

	return true;
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHORS);
}

////////////////////////////////    MAIN FUNCTIONS    ////////////////////////////////

// Fresh Bans
public fbans_player_banned_pre_f(
	const id,
	const uid,
	const player_steamid[],
	const player_ip[],
	const player_name[],
	const admin_ip[],
	const admin_steamid[],
	const admin_name[],
	const ban_type[],
	const ban_reason[],
	const bantime
) {
	SendFormatPunishmentMessage(
		.playerId = id,
		.adminId = get_user_index(admin_name),
		.duration = bantime,
		.reason = ban_reason,
		.punishment = "BAN"
	);
}

// [fork] Lite Bans
public user_banned_pre(
	banned_id,
	admin_id,
	ban_minutes,
	const ban_reason[LB_MAX_REASON_LENGTH]
) {
	SendFormatPunishmentMessage(
		.playerId = banned_id,
		.adminId = admin_id,
		.duration = ban_minutes,
		.reason = ban_reason,
		.punishment = "BAN"
	);
}

// AMXBans RBS
public amxbans_ban_pre(id, admin, bantime, bantype[], banreason[]) {
	SendFormatPunishmentMessage(
		.playerId = id,
		.adminId = admin,
		.duration = bantime,
		.reason = banreason,
		.punishment = "BAN"
	);
}

// Chat Additions: Gag
public CA_gag_setted(
	const target,
	name[],
	authID[],
	IP[],
	adminName[],
	adminAuthID[],
	adminIP[],
	reason[],
	time,
	gag_flags_s:flags,
	expireAt
) {
	SendFormatPunishmentMessage(
		.playerId = target,
		.adminId = get_user_index(adminName),
		.duration = (time == 0) ? 0 : (time / 60),
		.reason = reason,
		.punishment = "MUTE"
	);
}

// Ultimate GAG
public gag_gaged(id, player, flags, unixtime, reason[]) {
	SendFormatPunishmentMessage(
		.playerId = player,
		.adminId = id,
		.duration = (unixtime == 0) ? 0 : ((unixtime - get_systime()) / 60),
		.reason = reason,
		.punishment = "MUTE"
	);
}

// GameCMS GagManager
public OnCMSGagUserBlockAction(const id, eBlockFunc:iFunc, szData[BlockInfo]) {
	if(iFunc != eBlockFunc:BLOCK_FUNC_ADD)
		return;

	SendFormatPunishmentMessage(
		.playerId = id,
		.adminId = get_user_index(szData[GAdminNick]),
		.duration = szData[GBlockTime],
		.reason = szData[GBlockReason],
		.punishment = "MUTE"
	);
}

public SendFormatPunishmentMessage(const playerId, const adminId, const duration, const reason[], const punishment[]) {
	new playerIp[MAX_IP_WITH_PORT_LENGTH], adminIp[MAX_IP_WITH_PORT_LENGTH];
	get_user_ip(playerId, playerIp, charsmax(playerIp), 1);
	get_user_ip(adminId, adminIp, charsmax(adminIp), 1);

	new playerSteamId[MAX_AUTHID_LENGTH], adminSteamId[MAX_AUTHID_LENGTH];
	get_user_authid(playerId, playerSteamId, charsmax(playerSteamId));
	get_user_authid(adminId, adminSteamId, charsmax(adminSteamId));

	SetGlobalTransTarget(LANG_SERVER);
	
	if(adminSteamId[0] == EOS) {
		formatex(adminSteamId, charsmax(adminSteamId), "%l", "SERVER");
		formatex(adminIp, charsmax(adminIp), "%l", "SERVER");
	}
	
	new fmtMessage[MAX_MESSAGE_LENGTH];
	formatex(fmtMessage, charsmax(fmtMessage), "%l", "BAN_MUTE_MESSAGE");

	replace_string(fmtMessage, charsmax(fmtMessage), "$server$", Host[NAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$map$", Host[MAPNAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$player$", fmt("%n", playerId));
	replace_string(fmtMessage, charsmax(fmtMessage), "$admin$", fmt("%n", adminId));
	replace_string(fmtMessage, charsmax(fmtMessage), "$pip$", playerIp);
	replace_string(fmtMessage, charsmax(fmtMessage), "$aip$", adminIp);
	replace_string(fmtMessage, charsmax(fmtMessage), "$psid$", playerSteamId);
	replace_string(fmtMessage, charsmax(fmtMessage), "$asid$", adminSteamId);
	replace_string(fmtMessage, charsmax(fmtMessage), "$punish$", fmt("%l", punishment));
	replace_string(fmtMessage, charsmax(fmtMessage), "$reason$", reason);
	replace_string(fmtMessage, charsmax(fmtMessage), "$duration$",
	(duration == 0) ? fmt("%l", "TIME_PERMANENT") : MinutesToDurationString(duration));

	if(PluginSettings[SEND_PHOTO]) {
		tr_build_request(0, fmtMessage, MM_PHOTO, PluginSettings[PHOTO_URL]);
	} else {
		tr_build_request(0, fmtMessage, MM_MESSAGE);
	}
}