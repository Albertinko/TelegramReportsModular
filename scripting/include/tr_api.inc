////////////////////////////////////////////////////////////
////////////////							////////////////
////////		TELEGRAM REPORTS MODULAR API		////////
////////////////							////////////////
////////////////////////////////////////////////////////////

#if defined _tr_api_included
	#endinput
#endif
#define _tr_api_included

#define PLUGIN_VERSION	"5.1.0"
#define PLUGIN_AUTHORS	"HLDS.RUN Community"
#define PLUGIN_SOURCE	"https://github.com/Albertinko/TelegramReportsModular"

/**
 * Maximum buffer size required to store the message text
 */
#define MAX_MESSAGE_LENGTH 1024

/**
 * Maximum buffer size required for URL storage
 */
#define MAX_URL_LENGTH 256

/**
 * Structure of message methods
 */
enum _:MessageMethods {
	MM_MESSAGE = 0,
	MM_PHOTO
};

/**
 * Structure of language keys
 */
enum _:Times {
	TIME_YEARS = 0,
	TIME_MONTHS,
	TIME_WEEKS,
	TIME_DAYS,
	TIME_HOURS,
	TIME_MINUTES
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
 * Calls a function to build a request and then send a message to Telegram messenger
 *
 * @param playerId		ID of the player or server on whose behalf the message will be sent
 * @param message		Text of the message to send
 * @param urlMethod		Method of sending the message. MM_MESSAGE - sendMessage, MM_PHOTO - sendPhoto
 * @param photoUrl		URL of the photo. Must be filled in if MM_PHOTO method is selected
 *
 * @noreturn
 */
native tr_build_request(const playerId, const message[], const urlMethod, const photoUrl[]);

/**
 * Called when the message has been successfully sent
 *
 * @param playerId		ID of the player who sent the message
 * @param chatIndex		Order number of the chat to which the message was sent
 *
 * @noreturn
 */
forward tr_successful_message(const playerId, const chatIndex);

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

	times[TIME_YEARS] = minutes / 525600;
	minutes %= 525600;

	times[TIME_MONTHS] = minutes / 43200;
	minutes %= 43200;

	times[TIME_WEEKS] = minutes / 10080;
	minutes %= 10080;

	times[TIME_DAYS] = minutes / 1440;
	minutes %= 1440;

	times[TIME_HOURS] = minutes / 60;
	times[TIME_MINUTES] = minutes % 60;

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
 * @return				true - if loaded or false - if otherwise
 */
stock bool:is_core_loaded() {
	if(is_plugin_loaded("Telegram Reports: Core") == INVALID_PLUGIN_ID) {
		set_fail_state("The core plugin is not loaded!");
		return false;
	}

	return true;
}