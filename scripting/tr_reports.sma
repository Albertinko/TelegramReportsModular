#include <amxmodx>
#include <nvault>
#include <tr_api>

public stock const PLUGIN_NAME[] = "Telegram Reports: Reports";

new const CFG_FILE[]	=	"addons/amxmodx/configs/tr_configs/tr_settings.ini";
new const NVAULT_FILE[]	=	"telegram_reports";

enum Sections {
	SECTION_NONE = -1,
	SECTION_SETTINGS
};

new Sections:ParserCurSection;

enum _:Settings {
	REPORT_DELAY
};

new PluginSettings[Settings];

new Array:ArrayCommands;
new CommandsNum;

new HandlerVault;

public plugin_precache() {
	is_core_loaded();
	
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
		plugin_pause("ad");

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

	if(cmdArgs[cmdLen + 1] == EOS) {
		client_print_color(playerId, print_team_red, "%L", playerId, "ERROR_REPORT");
		return;
	}

	new steamId[MAX_AUTHID_LENGTH];
	get_user_authid(playerId, steamId, charsmax(steamId));

	new reportDelay = nvault_get(HandlerVault, steamId);
	new sysTime = get_systime();

	if(reportDelay && sysTime < reportDelay) {
		client_print_color(playerId, print_team_red, "%L", playerId,
		"REPORT_DELAY", MinutesToDurationString((reportDelay - sysTime) / 60));
		return;
	}

	tr_send_format_report_message(playerId, cmdArgs[cmdLen + 1]);
}

public tr_successful_message(playerId, chatIndex) {
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

	if(equal(section, "reports")) {
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
			} else if(equal(key, "DELAY")) { PluginSettings[REPORT_DELAY] = str_to_num(value) * 60; }
		}
	}

	return true;
}