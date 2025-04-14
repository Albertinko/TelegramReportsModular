#include <amxmodx>
#include <easy_http>
#include <tr_api>

public stock const PLUGIN_NAME[] = "Telegram Reports: Core";

new const DICT_FILE[]	=	"addons/amxmodx/configs/tr_configs/tr_dictionary.ini";
new const CFG_FILE[]	=	"addons/amxmodx/configs/tr_configs/tr_settings.ini";

enum Sections {
	SECTION_NONE = -1,
	SECTION_SETTINGS,
	SECTION_LANG_EN,
	SECTION_LANG_RU
};

new Sections:ParserCurSection;

enum _:Settings {
	SEND_MESSAGE[128],
	SEND_PHOTO[128],
	PHOTO_URL[128]
};

new PluginSettings[Settings];

enum _:ChatData {
	CHAT_ID[32],
	PUNISHMENT_THREAD_ID,
	REPORT_THREAD_ID
};

new Array:ArrayTelegramChats;
new TelegramChatsNum;

enum _:HostData {
	NAME[64],
	MAPNAME[64]
};

new Host[HostData];

enum _:Forward {
	SUCCESSFUL_REPORT
};

new Forwards[Forward];

public plugin_natives() {
	set_native_filter("native_filter_handler");

	register_native("tr_send_format_punishment_message", "_tr_send_format_punishment_message");
	register_native("tr_send_format_report_message", "_tr_send_format_report_message");
}

public plugin_precache() {
	register_plugin(PLUGIN_NAME, VERSION, AUTHORS);

	ArrayTelegramChats = ArrayCreate(ChatData);

	new INIParser:parser = INI_CreateParser();
	INI_SetReaders(parser, "ReadKeyValue", "ReadNewSection");
	INI_ParseFile(parser, DICT_FILE);
	INI_ParseFile(parser, CFG_FILE);
	INI_DestroyParser(parser);

	TelegramChatsNum = ArraySize(ArrayTelegramChats);

	if(!TelegramChatsNum)
		set_fail_state("Specify the Telegram chat id!");

	if(PluginSettings[SEND_MESSAGE][0] == EOS)
		set_fail_state("Specify the Telegram bot token!");
}

public plugin_init() {
	get_mapname(Host[MAPNAME], charsmax(Host[MAPNAME]));

	bind_pcvar_string(get_cvar_pointer("hostname"), Host[NAME], charsmax(Host[NAME]));

	formatex(PluginSettings[PHOTO_URL], charsmax(PluginSettings[PHOTO_URL]),
	"https://image.gametracker.com/images/maps/160x120/cs/%s.jpg", Host[MAPNAME]);

	Forwards[SUCCESSFUL_REPORT] = CreateMultiForward("tr_successful_report", ET_IGNORE, FP_CELL, FP_CELL);
}

public native_filter_handler(const nativeFunc[], nativeId, trapMode) {
	if(equal(nativeFunc, "tr_send_format_punishment_message"))
		return PLUGIN_HANDLED;

	if(equal(nativeFunc, "tr_send_format_report_message"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public _tr_send_format_punishment_message() {
	enum {
		arg_playerid = 1,
		arg_adminid,
		arg_duration,
		arg_reason,
		arg_punishment
	};

	new reason[64], punishment[32];
	get_string(arg_reason, reason, charsmax(reason));
	get_string(arg_punishment, punishment, charsmax(punishment));

	SendFormatPunishmentMessage(
		.playerId = get_param(arg_playerid),
		.adminId = get_param(arg_adminid),
		.duration = get_param(arg_duration),
		.reason = reason,
		.punishment = punishment
	);
}

public _tr_send_format_report_message() {
	enum {
		arg_playerid = 1,
		arg_report
	};

	new reportMessage[192];
	get_string(arg_report, reportMessage, charsmax(reportMessage));

	SendFormatReportMessage(
		.playerId = get_param(arg_playerid),
		.reportMessage = reportMessage
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
	
	new fmtMessage[1024];
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

	BuildRequest(0, fmtMessage, PluginSettings[SEND_PHOTO], PluginSettings[PHOTO_URL]);
}

public SendFormatReportMessage(const playerId, const reportMessage[]) {
	new playerIp[MAX_IP_WITH_PORT_LENGTH], playerSteamId[MAX_AUTHID_LENGTH];
	get_user_ip(playerId, playerIp, charsmax(playerIp), 1);
	get_user_authid(playerId, playerSteamId, charsmax(playerSteamId));
	
	new fmtMessage[1024];
	formatex(fmtMessage, charsmax(fmtMessage), "%L", LANG_SERVER, "REPORT_MESSAGE");

	replace_string(fmtMessage, charsmax(fmtMessage), "$server$", Host[NAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$map$", Host[MAPNAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$player$", fmt("%n", playerId));
	replace_string(fmtMessage, charsmax(fmtMessage), "$pip$", playerIp);
	replace_string(fmtMessage, charsmax(fmtMessage), "$psid$", playerSteamId);
	replace_string(fmtMessage, charsmax(fmtMessage), "$report$", reportMessage);

	BuildRequest(playerId, fmtMessage, PluginSettings[SEND_MESSAGE], "");
}

public BuildRequest(const playerId, const text[], const url[], const photoUrl[]) {
	for(new chatIndex, data[ChatData]; chatIndex < TelegramChatsNum; chatIndex++) {
		ArrayGetArray(ArrayTelegramChats, chatIndex, data);

		new EzJSON:object = ezjson_init_object();

		if(object == EzInvalid_JSON)
			continue;

		ezjson_object_set_string(object, "chat_id", data[CHAT_ID]);
		ezjson_object_set_string(object, "parse_mode", "HTML");

		if(photoUrl[0] != EOS) {
			ezjson_object_set_string(object, "photo", photoUrl);
			ezjson_object_set_string(object, "caption", text);

			if(data[PUNISHMENT_THREAD_ID] > INVALID_HANDLE)
				ezjson_object_set_number(object, "message_thread_id", data[PUNISHMENT_THREAD_ID]);
		} else {
			ezjson_object_set_string(object, "text", text);

			if(data[REPORT_THREAD_ID] > INVALID_HANDLE)
				ezjson_object_set_number(object, "message_thread_id", data[REPORT_THREAD_ID]);
		}

		new EzHttpOptions:options = ezhttp_create_options();

		ezhttp_option_set_body_from_json(options, object);
		ezjson_free(object);
		ezhttp_option_set_header(options, "Content-Type", "application/json");

		if(playerId) {
			new userData[2];
			userData[0] = playerId;
			userData[1] = chatIndex;
			ezhttp_option_set_user_data(options, userData, sizeof(userData));
		}

		ezhttp_post(url, "TelegramSendMessage", options);
	}
}

public TelegramSendMessage(EzHttpRequest:requestId) {
	if(ezhttp_get_error_code(requestId) != EZH_OK) {
		new error[64];
		ezhttp_get_error_message(requestId, error, charsmax(error));
		set_fail_state("%L", LANG_SERVER, "ERROR_RESPONSE", error);
		return;
	}

	new userData[2], playerId, chatIndex;
	ezhttp_get_user_data(requestId, userData);
	playerId = userData[0];
	chatIndex = userData[1];

	ExecuteForward(Forwards[SUCCESSFUL_REPORT], _, playerId, chatIndex);
}

public bool:ReadNewSection(INIParser:parser, const section[], bool:invalidTokens, bool:closeBracket) {	
	if(!closeBracket) {
		log_amx("Closing bracket was not detected! Current section name '%s'.", section);
		return false;
	}

	if(equal(section, "core")) {
		ParserCurSection = SECTION_SETTINGS;
		return true;
	}
	
	if(equal(section, "en")) {
		ParserCurSection = SECTION_LANG_EN;
		return true;
	} else if(equal(section, "ru")) {
		ParserCurSection = SECTION_LANG_RU;
		return true;
	}

	return false;
}

public bool:ReadKeyValue(INIParser:parser, const key[], const value[]) {
	switch(ParserCurSection) {
		case SECTION_NONE: { return false; }
		case SECTION_SETTINGS: {
			if(equal(key, "BOT_TOKEN")) {
				formatex(PluginSettings[SEND_MESSAGE], charsmax(PluginSettings[SEND_MESSAGE]), "https://api.telegram.org/bot%s/sendMessage?", value);
				formatex(PluginSettings[SEND_PHOTO], charsmax(PluginSettings[SEND_PHOTO]), "https://api.telegram.org/bot%s/sendPhoto?", value);
			} else if(equal(key, "CHATS_IDS")) {
				new tgChat[32], msgThread[2][32], data[ChatData], allTgChats[MAX_FMT_LENGTH];
				copy(allTgChats, charsmax(allTgChats), value);

				while(allTgChats[0] != 0 && strtok(allTgChats, tgChat, charsmax(tgChat), allTgChats, charsmax(allTgChats), ',')) {
					trim(tgChat), trim(allTgChats);
					strtok(tgChat, data[CHAT_ID], charsmax(data[CHAT_ID]), msgThread[0], charsmax(msgThread[]), ':');

					if(msgThread[0][0] != EOS) {
						trim(tgChat);
						strtok(msgThread[0], msgThread[0], charsmax(msgThread[]), msgThread[1], charsmax(msgThread[]), ':');
						data[PUNISHMENT_THREAD_ID] = str_to_num(msgThread[0]);
						data[REPORT_THREAD_ID] = str_to_num(msgThread[1]);
					} else {
						data[PUNISHMENT_THREAD_ID] = INVALID_HANDLE;
						data[REPORT_THREAD_ID] = INVALID_HANDLE;
					}

					ArrayPushArray(ArrayTelegramChats, data);
				}
			}
		}
		case SECTION_LANG_EN: {
			new fmtMessage[1024];
			copy(fmtMessage, charsmax(fmtMessage), value);
			ReplaceSpecChars(fmtMessage, charsmax(fmtMessage));
			AddTranslation("en", TransKey:CreateLangKey(key), fmtMessage);
		}
		case SECTION_LANG_RU: {
			new fmtMessage[1024];
			copy(fmtMessage, charsmax(fmtMessage), value);
			ReplaceSpecChars(fmtMessage, charsmax(fmtMessage));
			AddTranslation("ru", TransKey:CreateLangKey(key), fmtMessage);
		}
	}

	return true;
}

stock ReplaceSpecChars(string[], len) {
	replace_string(string, len, "^^1", "^1");
	replace_string(string, len, "^^3", "^3");
	replace_string(string, len, "^^4", "^4");
	replace_string(string, len, "^^n", "^n");
	replace_string(string, len, "^^t", "^t");
}