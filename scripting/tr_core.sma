////////////////////////////////    HEADER    ////////////////////////////////

#include <amxmodx>
#include <easy_http>
#include <tr_api>

#define PLUGIN_NAME	"Telegram Reports: Core"

////////////////////////////////    CONSTANTS    ////////////////////////////////

// URL to the GitHub repository to check for available updates
#define API_URL	"https://api.github.com/repos/Albertinko/TelegramReportsModular/releases/latest"

// The path to the dictionary file
#define DICT_FILE	"addons/amxmodx/configs/tr_configs/tr_dictionary.ini"

// The path to the configuration file
#define CFG_FILE	"addons/amxmodx/configs/tr_configs/tr_core.ini"

////////////////////////////////    GLOBAL VARIABLES    ////////////////////////////////

enum Sections {
	SECTION_NONE,
	SECTION_SETTINGS,
	SECTION_LANG_EN,
	SECTION_LANG_RU
};

new Sections:ParserCurSection;

new const SectionLang[Sections][] = {
	"",
	"",
	"en",
	"ru"
};

enum _:Settings {
	SEND_MESSAGE[MAX_URL_LENGTH],
	SEND_PHOTO[MAX_URL_LENGTH],
	CHECK_UPDATE
};

new PluginSettings[Settings];

enum _:ChatData {
	CHAT_ID[32],
	PUNISHMENT_THREAD_ID,
	REPORT_THREAD_ID
};

new Array:ArrayTelegramChats;
new TelegramChatsNum;

enum _:Forward {
	SUCCESSFUL_MESSAGE
};

new Forwards[Forward];

enum _:Semver {
	MAJOR = 0,
	MINOR,
	PATCH
};

////////////////////////////////    CONFIGURATION    ////////////////////////////////

public plugin_natives() {
	set_native_filter("native_filter_handler");

	register_native("tr_build_request", "native_tr_build_request");
}

public native_filter_handler(const nativeFunc[], nativeId, trapMode) {
	if(equal(nativeFunc, "tr_build_request"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public native_tr_build_request() {
	enum {
		arg_playerid = 1,
		arg_message,
		arg_urlmethod,
		arg_photourl
	};

	new playerId = get_param(arg_playerid);
	
	new message[MAX_MESSAGE_LENGTH];
	get_string(arg_message, message, charsmax(message));

	if(get_param(arg_urlmethod) == MM_MESSAGE) {
		BuildRequest(playerId, message, PluginSettings[SEND_MESSAGE], NULL_STRING);
	} else {
		new photoUrl[MAX_URL_LENGTH];
		get_string(arg_photourl, photoUrl, charsmax(photoUrl));

		BuildRequest(playerId, message, PluginSettings[SEND_PHOTO], photoUrl);
	}
}

public plugin_precache() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHORS);
	
	ParseConfig();

	if(!TelegramChatsNum)
		set_fail_state("Specify the Telegram chat id!");

	if(PluginSettings[SEND_MESSAGE][0] == EOS)
		set_fail_state("Specify the Telegram bot token!");
}

public ParseConfig() {
	ArrayTelegramChats = ArrayCreate(ChatData);

	new INIParser:parser = INI_CreateParser();
	INI_SetReaders(parser, "ReadKeyValue", "ReadNewSection");
	INI_ParseFile(parser, DICT_FILE);
	INI_ParseFile(parser, CFG_FILE);
	INI_DestroyParser(parser);

	TelegramChatsNum = ArraySize(ArrayTelegramChats);
}

public bool:ReadNewSection(INIParser:parser, const section[], bool:invalidTokens, bool:closeBracket) {	
	if(!closeBracket) {
		log_amx("Closing bracket was not detected! Current section name '%s'.", section);
		return false;
	}

	if(equal(section, "settings")) {
		ParserCurSection = SECTION_SETTINGS;
	} else if(equal(section, SectionLang[SECTION_LANG_EN])) {
		ParserCurSection = SECTION_LANG_EN;
	} else if(equal(section, SectionLang[SECTION_LANG_RU])) {
		ParserCurSection = SECTION_LANG_RU;
	} else {
		return false;
	}

	return true;
}

public bool:ReadKeyValue(INIParser:parser, const key[], const value[]) {
	switch(ParserCurSection) {
		case SECTION_NONE: {
			return false;
		}
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
						strtok(msgThread[0], msgThread[0], charsmax(msgThread[]), msgThread[1], charsmax(msgThread[]), ':');
						data[PUNISHMENT_THREAD_ID] = str_to_num(msgThread[0]);
						data[REPORT_THREAD_ID] = str_to_num(msgThread[1]);
					} else {
						data[PUNISHMENT_THREAD_ID] = INVALID_HANDLE;
						data[REPORT_THREAD_ID] = INVALID_HANDLE;
					}

					ArrayPushArray(ArrayTelegramChats, data);
				}
			} else if(equal(key, "CHECK_UPDATE")) {
				PluginSettings[CHECK_UPDATE] = str_to_num(value);
			}
		}
		default: {
			new lang[3];
			copy(lang, charsmax(lang), SectionLang[ParserCurSection]);
			RegisterTranslationKey(lang, key, value);
		}
	}

	return true;
}

public plugin_init() {
	if(PluginSettings[CHECK_UPDATE])
		ezhttp_get(API_URL, "CheckUpdateComplete");

	Forwards[SUCCESSFUL_MESSAGE] = CreateMultiForward("tr_successful_message", ET_IGNORE, FP_CELL, FP_CELL);
}

////////////////////////////////    MAIN FUNCTIONS    ////////////////////////////////

public BuildRequest(const playerId, const message[], const urlMethod[], const photoUrl[]) {
	for(new chatIndex, data[ChatData]; chatIndex < TelegramChatsNum; chatIndex++) {
		ArrayGetArray(ArrayTelegramChats, chatIndex, data);

		new EzJSON:object = ezjson_init_object();

		if(object == EzInvalid_JSON)
			continue;

		ezjson_object_set_string(object, "chat_id", data[CHAT_ID]);
		ezjson_object_set_string(object, "parse_mode", "HTML");

		if(photoUrl[0] != EOS) {
			ezjson_object_set_string(object, "photo", photoUrl);
			ezjson_object_set_string(object, "caption", message);

			if(data[PUNISHMENT_THREAD_ID] > INVALID_HANDLE)
				ezjson_object_set_number(object, "message_thread_id", data[PUNISHMENT_THREAD_ID]);
		} else {
			ezjson_object_set_string(object, "text", message);

			if(data[REPORT_THREAD_ID] > INVALID_HANDLE)
				ezjson_object_set_number(object, "message_thread_id", data[REPORT_THREAD_ID]);
		}

		new EzHttpOptions:options = ezhttp_create_options();
		ezhttp_option_set_body_from_json(options, object);
		ezhttp_option_set_header(options, "Content-Type", "application/json");

		ezjson_free(object);

		if(playerId) {
			new userData[2];
			userData[0] = playerId;
			userData[1] = chatIndex;
			ezhttp_option_set_user_data(options, userData, sizeof(userData));
		}

		ezhttp_post(urlMethod, "TelegramMessageComplete", options);
	}
}

public TelegramMessageComplete(EzHttpRequest:requestId) {
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

	ExecuteForward(Forwards[SUCCESSFUL_MESSAGE], _, playerId, chatIndex);
}

public CheckUpdateComplete(EzHttpRequest:requestId) {
	if(ezhttp_get_error_code(requestId) != EZH_OK) {
		new error[64];
		ezhttp_get_error_message(requestId, error, charsmax(error));
		set_fail_state("%L", LANG_SERVER, "ERROR_RESPONSE", error);
		return;
	}

	new EzJSON:requestHandle = ezhttp_parse_json_response(requestId);

	if(requestHandle == EzInvalid_JSON)
		return;

	new buffer[128];
	ezjson_object_get_string(requestHandle, "tag_name", buffer, charsmax(buffer));

	ezjson_free(requestHandle);

	if(CompareVersion(buffer, PLUGIN_VERSION) == 1) {
		new curTime[32];
		get_time("%m/%d/%Y - %H:%M:%S", curTime, charsmax(curTime));
		server_print("L %s: %L", curTime, LANG_SERVER, "UPDATE_AVAILABLE");
	}
}

////////////////////////////////    STOCK FUNCTIONS    ////////////////////////////////

stock CompareVersion(const ver1[], const ver2[]) {
	new version[2][Semver];
	ParseVersion(ver1, version[0]);
	ParseVersion(ver2, version[1]);

	for(new i; i < Semver; i++) {
		if(version[0][i] > version[1][i])
			return 1;

		if(version[0][i] < version[1][i])
			return -1;
	}

	return 0;
}

stock ParseVersion(const version[], semver[Semver]) {
	new tempVersion[32];
	
	if(version[0] == 'v' || version[0] == 'V') {
		copy(tempVersion, charsmax(tempVersion), version[1]);
	} else {
		copy(tempVersion, charsmax(tempVersion), version);
	}

	new tokens[3][8];
	explode_string(tempVersion, ".", tokens, sizeof(tokens), sizeof(tokens[]));

	semver[MAJOR] = str_to_num(tokens[0]);
	semver[MINOR] = str_to_num(tokens[1]);
	semver[PATCH] = str_to_num(tokens[2]);
}

stock ReplaceSpecChars(string[], len) {
	replace_string(string, len, "^^1", "^1");
	replace_string(string, len, "^^3", "^3");
	replace_string(string, len, "^^4", "^4");
	replace_string(string, len, "^^n", "^n");
	replace_string(string, len, "^^t", "^t");
}

stock RegisterTranslationKey(const lang[3], const key[], const phrase[]) {
	new fmtMessage[MAX_MESSAGE_LENGTH];
	copy(fmtMessage, charsmax(fmtMessage), phrase);
	ReplaceSpecChars(fmtMessage, charsmax(fmtMessage));
	AddTranslation(lang, CreateLangKey(key), fmtMessage);
}