////////////////////////////////////
////////					////////
////	Telegram Reports API	////
////////					////////
////////////////////////////////////

#if defined _tr_api_included
	#endinput
#endif
#define _tr_api_included

public stock const VERSION[]	=	"4.0.0";
public stock const AUTHORS[]	=	"DEV-CS.RU Community";
public stock const SOURCE[]		=	"https://github.com/Albertinko/TelegramReportsModular";

/**
 * The structure of language keys
 */
enum _:Times {
	YEARS = 0,
	MONTHS,
	WEEKS,
	DAYS,
	HOURS,
	MINUTES
};

/**
 * Language keys
 */
new TimeLang[][] = {
	"TIME_YEARS",
	"TIME_MONTHS",
	"TIME_WEEKS",
	"TIME_DAYS",
	"TIME_HOURS",
	"TIME_MINUTES"
};

/**
 * Calls a function to format the data and then send a punishment message
 *
 * @param playerId			ID of the player who received the punishment
 * @param adminId			ID of the admin who issued the punishment
 * @param duration			Duration of punishment
 * @param reason			Reason of punishment
 * @param punishment		Type of punishment(BAN, GAG)
 *
 * @noreturn
 */
native tr_send_format_punishment_message(const playerId, const adminId, const duration, const reason[], const punishment[]);

/**
 * Calls a function to format the data and then send a report message
 *
 * @param playerId			ID of the player who sent the report
 * @param reportMessage		Message of report
 *
 * @noreturn
 */
native tr_send_format_report_message(const playerId, const reportMessage[]);

/**
 * Called when the report has been successfully sent
 *
 * @param playerId		ID of the player who sent the report
 * @param chatIndex		Order number of the chat to which the report was sent
 *
 * @noreturn
 */
forward tr_successful_report(playerId, chatIndex);

/**
 * Converting an integer value of minutes to a string of duration
 *
 * @param minutes		Integer value in minutes
 *
 * @return				String with converted minutes to duration
 */
stock any:MinutesToDurationString(minutes) {
	new duration[MAX_FMT_LENGTH];
	
	if(minutes <= 0)
		return duration;

	new times[Times];

	times[YEARS] = minutes / 525600;
	minutes %= 525600;

	times[MONTHS] = minutes / 43200;
	minutes %= 43200;

	times[WEEKS] = minutes / 10080;
	minutes %= 10080;

	times[DAYS] = minutes / 1440;
	minutes %= 1440;

	times[HOURS] = minutes / 60;
	times[MINUTES] = minutes % 60;

	for(new i, len; i < Times; i++) {
		if(times[i] == 0)
			continue;

		len += formatex(duration[len], charsmax(duration) - len,
		"%d %L ", times[i], LANG_SERVER, TimeLang[i]);
	}

	trim(duration);

	return duration;
}

/**
 * Checks whether the core plugin is loaded. In case of failure, it will stop the plugin.
 *
 * @return		true - if loaded or false - if otherwise
 */
stock bool:is_core_loaded() {
	if(is_plugin_loaded("Telegram Reports: Core") == INVALID_PLUGIN_ID)
		set_fail_state("The core plugin is not loaded!");
}