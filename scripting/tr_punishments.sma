#include <amxmodx>
#include <tr_api>

public stock const PLUGIN_NAME[] = "Telegram Reports: Punishments";

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
forward user_banned_pre(id, admin_id, ban_minutes, reason[]);

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
#define MAX_REASON_LENGTH 100

enum _:BlockInfo {
	GBid,
	GBlockType,
	GExpired,
	GAdminId,
	GCreated,
	GBlockTime,
	GAuthId[MAX_AUTHID_LENGTH],
	GName[MAX_NAME_LENGTH],
	GBlockReason[MAX_REASON_LENGTH],
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
	is_core_loaded();
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, VERSION, AUTHORS);
}

// Fresh Bans
public fbans_player_banned_pre_f(
	const id,
	const userid,
	const szSteamID[],
	const szIp[],
	const szName[],
	const szAdminIp[],
	const szAdminSteamID[],
	const szAdminName[],
	const ban_type[],
	const szReason[],
	const bantime
) {
	tr_send_format_punishment_message(
		.playerId = id,
		.adminId = get_user_index(szAdminName),
		.duration = bantime,
		.reason = szReason,
		.punishment = "BAN"
	);
}

// [fork] Lite Bans
public user_banned_pre(id, admin_id, ban_minutes, reason[]) {
	tr_send_format_punishment_message(
		.playerId = id,
		.adminId = admin_id,
		.duration = ban_minutes,
		.reason = reason,
		.punishment = "BAN"
	);
}

// AMXBans RBS
public amxbans_ban_pre(id, admin, bantime, bantype[], banreason[]) {
	tr_send_format_punishment_message(
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
	szName[],
	authID[],
	IP[],
	adminName[],
	adminAuthID[],
	adminIP[],
	szReason[],
	iTime,
	gag_flags_s:flags,
	expireAt
) {
	tr_send_format_punishment_message(
		.playerId = target,
		.adminId = get_user_index(adminName),
		.duration = (iTime == 0) ? 0 : (iTime / 60),
		.reason = szReason,
		.punishment = "MUTE"
	);
}

// Ultimate GAG
public gag_gaged(id, player, flags, unixtime, reason[]) {
	tr_send_format_punishment_message(
		.playerId = player,
		.adminId = id,
		.duration = (unixtime == 0) ? 0 : ((unixtime - get_systime()) / 60),
		.reason = reason,
		.punishment = "MUTE"
	);
}

// GameCMS GagManager
public OnCMSGagUserBlockAction(const id, eBlockFunc:iFunc, szData[BlockInfo]) {
	if(iFunc == eBlockFunc:BLOCK_FUNC_ADD)
		tr_send_format_punishment_message(
			.playerId = id,
			.adminId = szData[GAdminId],
			.duration = szData[GBlockTime],
			.reason = szData[GBlockReason],
			.punishment = "MUTE"
		);
}