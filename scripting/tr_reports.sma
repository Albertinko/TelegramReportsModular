#include <amxmodx>
#include <nvault>
#include <tr_api>

public stock const PLUGIN_NAME[] = "Telegram Reports: Reports";

new const CFG_FILE[]	=	"addons/amxmodx/configs/tr_configs/tr_reports.ini";
new const NVAULT_FILE[]	=	"telegram_reports";

enum Sections {
	SECTION_NONE = -1,
	SECTION_SETTINGS
};

new Sections:ParserCurSection;

enum _:Settings {
	REPORT_DELAY,
	SEND_PHOTO,
	PHOTO_URL[MAX_URL_LENGTH]
};

new PluginSettings[Settings];

enum _:HostData {
	NAME[64],
	MAPNAME[64]
};

new Host[HostData];

new Array:ArrayCommands;
new CommandsNum;

new HandlerVault;

public plugin_precache() {
	is_core_loaded();

	get_mapname(Host[MAPNAME], charsmax(Host[MAPNAME]));
	bind_pcvar_string(get_cvar_pointer("hostname"), Host[NAME], charsmax(Host[NAME]));
	
	ArrayCommands = ArrayCreate(32);

	new INIParser:parser = INI_CreateParser();
	INI_SetReaders(parser, "ReadKeyValue", "ReadNewSection");
	INI_ParseFile(parser, CFG_FILE);
	INI_DestroyParser(parser);

	CommandsNum = ArraySize(ArrayCommands);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, VERSION, AUTHORS);

	if(!CommandsNum)
		pause("ad");

	register_clcmd("say", "SayReport");
	register_clcmd("say_team", "SayReport");
}

public plugin_cfg() {
	if((HandlerVault = nvault_open(NVAULT_FILE)) == INVALID_HANDLE)
		set_fail_state("Error opening nVault!");

	nvault_prune(HandlerVault, 0, get_systime() - PluginSettings[REPORT_DELAY]);
}

public plugin_end() {
	nvault_close(HandlerVault);
}

public SayReport(playerId) {
	new cmd[32], cmdArgs[192];
	new bool:cmdFound;
	new cmdLen;

	read_argv(1, cmdArgs, charsmax(cmdArgs));

	for(new i; i < CommandsNum; i++) {
		ArrayGetString(ArrayCommands, i, cmd, charsmax(cmd));
		cmdLen = strlen(cmd);

		if(equali(cmd, cmdArgs, cmdLen) && (cmdArgs[cmdLen] == EOS || cmdArgs[cmdLen] == ' ')) {
			cmdFound = true;
			break;
		}
	}

	trim(cmdArgs[cmdLen + 1]);

	if(!cmdFound)
		return;

	SetGlobalTransTarget(playerId);

	if(cmdArgs[cmdLen + 1] == EOS) {
		client_print_color(playerId, print_team_red, "%l", "ERROR_REPORT");
		return;
	}

	new steamId[MAX_AUTHID_LENGTH];
	get_user_authid(playerId, steamId, charsmax(steamId));

	new reportDelay = nvault_get(HandlerVault, steamId);
	new sysTime = get_systime();

	if(reportDelay && sysTime < reportDelay) {
		new delayInMinutes = (reportDelay - sysTime) / 60;
		client_print_color(playerId, print_team_red, "%l", "REPORT_DELAY",
		delayInMinutes == 0 ? fmt("%l", "LESS_MINUTE") : MinutesToDurationString(delayInMinutes));
		return;
	}

	SendFormatReportMessage(playerId, cmdArgs[cmdLen + 1]);
}

public SendFormatReportMessage(const playerId, const reportMessage[]) {
	new playerIp[MAX_IP_WITH_PORT_LENGTH], playerSteamId[MAX_AUTHID_LENGTH];
	get_user_ip(playerId, playerIp, charsmax(playerIp), 1);
	get_user_authid(playerId, playerSteamId, charsmax(playerSteamId));

	new fmtMessage[MAX_MESSAGE_LENGTH];
	formatex(fmtMessage, charsmax(fmtMessage), "%L", LANG_SERVER, "REPORT_MESSAGE");

	replace_string(fmtMessage, charsmax(fmtMessage), "$server$", Host[NAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$map$", Host[MAPNAME]);
	replace_string(fmtMessage, charsmax(fmtMessage), "$player$", fmt("%n", playerId));
	replace_string(fmtMessage, charsmax(fmtMessage), "$pip$", playerIp);
	replace_string(fmtMessage, charsmax(fmtMessage), "$psid$", playerSteamId);
	replace_string(fmtMessage, charsmax(fmtMessage), "$report$", reportMessage);

	if(PluginSettings[SEND_PHOTO])
		tr_build_request(playerId, fmtMessage, MM_PHOTO, PluginSettings[PHOTO_URL]);
	else
		tr_build_request(playerId, fmtMessage, MM_MESSAGE, "");
}

public tr_successful_message(const playerId, const chatIndex) {
	if(is_user_connected(playerId) && chatIndex == 0) {
		new steamId[MAX_AUTHID_LENGTH];
		get_user_authid(playerId, steamId, charsmax(steamId));

		new reportDelay[32];
		num_to_str(get_systime() + PluginSettings[REPORT_DELAY], reportDelay, charsmax(reportDelay));

		nvault_set(HandlerVault, steamId, reportDelay);

		client_print_color(playerId, print_team_blue, "%L", playerId, "SUCCESSFUL_REPORT");
	}
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
		case SECTION_NONE: { return false; }
		case SECTION_SETTINGS: {
			if(equal(key, "COMMANDS")) {
				new cmd[32], allCmds[MAX_FMT_LENGTH];
				copy(allCmds, charsmax(allCmds), value);

				while(allCmds[0] != 0 && strtok(allCmds, cmd, charsmax(cmd), allCmds, charsmax(allCmds), ',')) {
					trim(cmd), trim(allCmds);
					ArrayPushString(ArrayCommands, cmd);
				}
			} else if(equal(key, "DELAY")) {
				PluginSettings[REPORT_DELAY] = str_to_num(value) * 60;
			} else if(equal(key, "SEND_PHOTO")) {
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