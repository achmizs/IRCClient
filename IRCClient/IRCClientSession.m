//
//	IRCClientSession.m
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

/********************************/
#pragma mark Defines and includes
/********************************/

#define IRCCLIENTVERSION "2.0a5"

#import "IRCClientSession.h"
#import "IRCClientChannel.h"
#import "IRCClientChannel_Private.h"

#import "NSArray+SA_NSArrayExtensions.h"
#import "NSData+SA_NSDataExtensions.h"
#import "NSString+SA_NSStringExtensions.h"
#import "NSRange-Conventional.h"

/********************************************/
#pragma mark - Callback function declarations
/********************************************/

static void onEvent			(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onNumericEvent	(irc_session_t *session, unsigned int event, const char *origin, const char **params, unsigned int count);
static void onDCCChatRequest(irc_session_t *session, const char *nick, const char *addr, irc_dcc_t dccid);
static void onDCCSendRequest(irc_session_t *session, const char *nick, const char *addr, const char *filename, size_t size, irc_dcc_t dccid);

static NSDictionary* ircNumericCodeList;

/***************************************************/
#pragma mark - IRCClientSession class implementation
/***************************************************/

@implementation IRCClientSession {
	irc_callbacks_t _callbacks;
	irc_session_t *_irc_session;

	NSMutableDictionary <NSData *, IRCClientChannel *> *_channels;
}

/******************************/
#pragma mark - Custom accessors
/******************************/

-(NSDictionary <NSData *, IRCClientChannel *> *) channels {
	return [_channels copy];
}

-(bool) isConnected {
	return irc_is_connected(_irc_session);
}

+(NSDictionary *) ircNumericCodes {
	if (ircNumericCodeList == nil)
		[IRCClientSession loadNumericCodes];

	return ircNumericCodeList;
}

/********************************************/
#pragma mark - Initializers & factory methods
/********************************************/

+(instancetype) session {
	return [self new];
}

-(instancetype) init {
	if (!(self = [super init]))
		return nil;

	_callbacks.event_connect		= onEvent;
	_callbacks.event_ping			= onEvent;
	_callbacks.event_nick			= onEvent;
	_callbacks.event_quit			= onEvent;
	_callbacks.event_join			= onEvent;
	_callbacks.event_part			= onEvent;
	_callbacks.event_mode			= onEvent;
	_callbacks.event_umode			= onEvent;
	_callbacks.event_topic			= onEvent;
	_callbacks.event_kick			= onEvent;
	_callbacks.event_error			= onEvent;
	_callbacks.event_channel		= onEvent;
	_callbacks.event_privmsg		= onEvent;
	_callbacks.event_server_msg		= onEvent;
	_callbacks.event_notice			= onEvent;
	_callbacks.event_channel_notice	= onEvent;
	_callbacks.event_server_notice	= onEvent;
	_callbacks.event_invite			= onEvent;
	_callbacks.event_ctcp_req		= onEvent;
	_callbacks.event_ctcp_rep		= onEvent;
	_callbacks.event_ctcp_action	= onEvent;
	_callbacks.event_unknown		= onEvent;
	_callbacks.event_numeric		= onNumericEvent;
	_callbacks.event_dcc_chat_req	= onDCCChatRequest;
	_callbacks.event_dcc_send_req	= onDCCSendRequest;

	_irc_session = irc_create_session(&_callbacks);

	if (!_irc_session) {
		NSLog(@"Could not create irc_session.");
		return nil;
	}

	// Strip server info from nicks.
	//	irc_option_set(_irc_session, LIBIRC_OPTION_STRIPNICKS);

	// Set debug mode.
	//	irc_option_set(_irc_session, LIBIRC_OPTION_DEBUG);

	irc_set_ctx(_irc_session, (__bridge void *)(self));

	unsigned int high, low;
	irc_get_version (&high, &low);

	_version = [[NSString stringWithFormat:@"IRCClient Framework v%s (Said Achmiz) - libirc v%d.%d (Georgy Yunaev)",
				 IRCCLIENTVERSION,
				 high,
				 low] dataAsUTF8];

	_channels = [NSMutableDictionary dictionary];
	_encoding = NSUTF8StringEncoding;

	_userInfo = [NSMutableDictionary dictionary];

	return self;
}

-(void) dealloc {
	if (irc_is_connected(_irc_session)) {
		NSLog(@"Warning: IRC Session is not disconnected on dealloc");
	}

	irc_destroy_session(_irc_session);
}

/***************************/
#pragma mark - Class methods
/***************************/

+(NSData *) nickFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfNickUserSeparator = [nickUserHost rangeOfData:[NSData dataFromCString:"!"]
														 options:(NSDataSearchOptions) 0
														   range:NSRangeMake(0, nickUserHost.length)];

	return (rangeOfNickUserSeparator.location == NSNotFound
			? nickUserHost
			: [nickUserHost subdataWithRange:NSRangeMake(0, rangeOfNickUserSeparator.location)]);
}

+(NSData *) userFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfNickUserSeparator = [nickUserHost rangeOfData:[NSData dataFromCString:"!"]
														 options:(NSDataSearchOptions) 0
														   range:NSRangeMake(0, nickUserHost.length)];

	NSRange rangeOfUserHostSeparator = [nickUserHost rangeOfData:[NSData dataFromCString:"@"]
														 options:(NSDataSearchOptions) 0
														   range:NSRangeMake(0, nickUserHost.length)];

	return ((   rangeOfNickUserSeparator.location == NSNotFound
			 || rangeOfUserHostSeparator.location == NSNotFound)
			? [NSData data]
			: [nickUserHost subdataWithRange:NSRangeMake(rangeOfNickUserSeparator.location + 1,
														 rangeOfUserHostSeparator.location - (rangeOfNickUserSeparator.location + 1))]);
}

+(NSData *) hostFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfUserHostSeparator = [nickUserHost rangeOfData:[NSData dataFromCString:"@"]
														 options:(NSDataSearchOptions) 0
														   range:NSRangeMake(0, nickUserHost.length)];

	return (rangeOfUserHostSeparator.location == NSNotFound
			? [NSData data]
			: [nickUserHost subdataWithRange:NSRangeMake(rangeOfUserHostSeparator.location + 1,
														 nickUserHost.length - (rangeOfUserHostSeparator.location + 1))]);
}

/*************************************/
#pragma mark - Class methods (private)
/*************************************/

+(void) loadNumericCodes {
	NSString* numericCodeListPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IRC_Numerics"
																					 ofType:@"plist"];
	ircNumericCodeList = [NSDictionary dictionaryWithContentsOfFile:numericCodeListPath];
	if (ircNumericCodeList) {
		NSLog(@"IRC numeric codes list loaded successfully.\n");
	} else {
		NSLog(@"Could not load IRC numeric codes list!\n");
	}
}

/******************************/
#pragma mark - Instance methods
/******************************/

-(int) connect {
	return irc_connect(_irc_session,
					   _server.terminatedCString,
					   (unsigned short) _port,
					   (_password.length > 0 ? _password.terminatedCString : NULL),
					   _nickname.terminatedCString,
					   _username.terminatedCString,
					   _realname.terminatedCString);
}

-(void) disconnect {
	irc_disconnect(_irc_session);
}

-(void) run {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
			irc_run(_irc_session);
		}
		[_delegate disconnected:self];
	});
}

-(int) setNickname:(NSData *)nickname 
		  username:(NSData *)username 
		  realname:(NSData *)realname {
	if (self.isConnected) {
		return 0;
	} else {
		_nickname = nickname;
		_username = username;
		_realname = realname;
		
		return 1;
	}
}

/**************************/
#pragma mark - IRC commands
/**************************/

-(int) sendRaw:(NSData *)message {
	return irc_send_raw(_irc_session,
						message.terminatedCString);
}

-(int) quit:(NSData *)reason {
	return irc_send_raw(_irc_session,
						"QUIT :%s",
						(reason
						 ? reason.terminatedCString
						 : "quit"));
}

-(int) join:(NSData *)channel 
		key:(NSData *)key {
	if (!channel || channel.length == 0)
		return LIBIRC_ERR_STATE;

	if (key && key.length > 0)
		return irc_send_raw(_irc_session,
							"JOIN %s :%s",
							channel.terminatedCString,
							key.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"JOIN %s",
							channel.terminatedCString);
}

-(int) names:(NSData *)channel {
	if (channel)
		return irc_send_raw(_irc_session,
							"NAMES %s",
							channel.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"NAMES");
}

-(int) list:(NSData *)channel {
	if (channel)
		return irc_send_raw(_irc_session,
							"LIST %s",
							channel.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"LIST");
}

-(int) userMode:(NSData *)mode {
	if (mode)
		return irc_send_raw(_irc_session,
							"MODE %s %s",
							_nickname.terminatedCString,
							mode.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"MODE %s",
							_nickname.terminatedCString);
}

-(int) nick:(NSData *)newnick {
	if (!newnick || newnick.length == 0)
		return LIBIRC_ERR_INVAL;

	return irc_send_raw(_irc_session,
						"NICK %s",
						newnick.terminatedCString);
}

-(int) who:(NSData *)nickmask {
	if (!nickmask || nickmask.length == 0)
		return LIBIRC_ERR_INVAL;

	return irc_send_raw(_irc_session,
						"WHO %s",
						nickmask.terminatedCString);
}

-(int) whois:(NSData *)nick {
	if (!nick || nick.length == 0)
		return LIBIRC_ERR_INVAL;

	return irc_send_raw(_irc_session,
						"WHOIS %s",
						nick.terminatedCString);
}

-(int) message:(NSData *)message 
			to:(NSData *)target {
	if (   !target  || target.length == 0
		|| !message || message.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :%s",
						target.terminatedCString,
						irc_color_convert_to_mirc(message.terminatedCString));
}

-(int) action:(NSData *)action
		   to:(NSData *)target {
	if (   !target || target.length == 0
		|| !action || action.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :\x01" "ACTION %s\x01",
						target.terminatedCString,
						irc_color_convert_to_mirc(action.terminatedCString));
}

-(int) notice:(NSData *)notice 
		   to:(NSData *)target {
	if (   !target || target.length == 0
		|| !notice || notice.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"NOTICE %s :%s",
						target.terminatedCString,
						notice.terminatedCString);
}

-(int) ctcpRequest:(NSData *)request 
			target:(NSData *)target {
	if (   !target  || target.length == 0
		|| !request || request.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :\x01%s\x01",
						target.terminatedCString,
						request.terminatedCString);
}

-(int) ctcpReply:(NSData *)reply 
		  target:(NSData *)target {
	if (   !target || target.length == 0
		|| !reply  || reply.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"NOTICE %s :\x01%s\x01",
						target.terminatedCString,
						reply.terminatedCString);
}

/********************************/
#pragma mark - IRC event handlers
/********************************/

-(void) ircEventReceived:(const char *)event
					from:(const char *)origin
			  withParams:(const char **)params
				   count:(unsigned int)count {
	typedef enum : NSUInteger {
		SA_IRC_ParseColorCodes,
		SA_IRC_StripColorCodes,
		SA_IRC_IgnoreColorCodes,
	} SA_IRC_ColorCodeHandling;

	// TODO: Support setting this somehow...
	SA_IRC_ColorCodeHandling whatAboutColors = SA_IRC_ParseColorCodes;

	NSMutableArray <NSData *> *params_array;
	if ((whatAboutColors != SA_IRC_IgnoreColorCodes)
		&& (   !strcmp(event, "PRIVMSG")
			|| !strcmp(event, "CHANMSG")
			|| !strcmp(event, "SERVMSG")
			|| !strcmp(event, "PRIVNOTICE")
			|| !strcmp(event, "CHANNOTICE")
			|| !strcmp(event, "SERVNOTICE")
			|| !strcmp(event, "CTCP_ACTION")
		)) {
			char* (*process_color_codes) (const char *) = (whatAboutColors == SA_IRC_ParseColorCodes
														   ? irc_color_convert_from_mirc
														   : irc_color_strip_from_mirc);

			params_array = [NSMutableArray arrayWithCapacity:count];
			for (NSUInteger i = 0; i < count; i++) {
				[params_array addObject:[NSData dataFromCString:(*process_color_codes)(params[i])]];
			}
	} else {
		params_array = (NSMutableArray *) [NSArray arrayOfCStringData:params
																count:count];
	}

	NSData *origin_data = origin ? [NSData dataFromCString:origin] : nil;
	NSData *param_0_data = (count > 0
							? params_array[0]
							: nil);
	NSData *param_1_data = (count > 1
							? params_array[1]
							: nil);
	NSData *param_2_data = (count > 2
							? params_array[2]
							: nil);

	if (!strcmp(event, "CONNECT")) {
		/*!
		 * The ‘on_connect’ event is triggered when the client successfully
		 * connects to the server, and could send commands to the server.
		 * No extra params supplied; \a params is 0.
		 */
		[_delegate connectionSucceeded:self];
	} else if (!strcmp(event, "PING")) {
		// TODO: the part about LIBIRC_OPTION_PING_PASSTHROUGH seems to be a lie??
		// But see also LIBIRC_OPTION_IGNORE_PING???
		/*!
		 * The ‘ping’ event is triggered when the client receives a PING message.
		 * It is only generated if the LIBIRC_OPTION_PING_PASSTHROUGH option is set;
		 * otherwise, the library responds to PING messages automatically.
		 *
		 * \param origin the person, who generated the ping.
		 * \param params[0] mandatory, contains who knows what.
		 */
		if ([_delegate respondsToSelector:@selector(ping:from:session:)]) {
			[_delegate ping:param_0_data
					   from:origin_data
					session:self];
		}
	} else if (!strcmp(event, "NICK")) {
		/*!
		 * The ‘nick’ event is triggered when the client receives a NICK message,
		 * meaning that someone (including you) on a channel with the client has
		 * changed their nickname.
		 *
		 * \param origin The person who changed their nick. Note that it can be you!
		 * \param params[0] Mandatory; contains the new nick.
		 */
		[self nickChangedFrom:origin_data
						   to:param_0_data];
	} else if (!strcmp(event, "QUIT")) {
		/*!
		 * The ‘quit’ event is triggered upon receipt of a QUIT message, which
		 * means that someone on a channel with the client has disconnected.
		 *
		 * \param origin The person who is disconnected.
		 * \param params[0] Optional; contains the reason message (user-specified).
		 */
		[_delegate userQuit:origin_data
				 withReason:param_0_data
					session:self];
	} else if (!strcmp(event, "JOIN")) {
		/*!
		 * The ‘join’ event is triggered upon receipt of a JOIN message, which
		 * means that someone has entered a channel that the client is on.
		 *
		 * \param origin The person who joined the channel. By comparing it with
		 *               your own nickname, you can check whether your JOIN
		 *               command succeed.
		 * \param params[0] Mandatory; contains the channel name.
		 */
		[self userJoined:origin_data
				 channel:param_0_data];
	} else if (!strcmp(event, "PART")) {
		/*!
		 * The ‘part’ event is triggered upon receipt of a PART message, which
		 * means that someone has left a channel that the client is on.
		 *
		 * \param Origin The person who left the channel. By comparing it with
		 *               your own nickname, you can check whether your PART
		 *               command succeed.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the reason message (user-defined).
		 */
		[self userParted:origin_data
				 channel:param_0_data
			  withReason:param_1_data];
	} else if (!strcmp(event, "MODE")) {
		/*!
		 * The ‘mode’ event is triggered upon receipt of a channel MODE message,
		 * which means that someone on a channel with the client has changed the
		 * channel’s parameters.
		 *
		 * \param origin The person who changed the channel mode.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Mandatory; contains the changed channel mode, like
		 *        ‘+t’, ‘-i’, and so on.
		 * \param params[2] Optional; contains the mode argument (for example, a
		 *      key for +k mode, or user who got channel operator status for
		 *      +o mode)
		 */
		IRCClientChannel *channel = _channels[param_0_data];
		[channel modeSet:param_1_data
			  withParams:param_2_data
					  by:origin_data];
	} else if (!strcmp(event, "UMODE")) {
		/*!
		 * The ‘umode’ event is triggered upon receipt of a user MODE message,
		 * which means that your user mode has been changed.
		 *
		 * \param origin The person who changed the user mode.
		 * \param params[0] Mandatory; contains the user changed mode, like
		 *        ‘+t’, ‘-i’ and so on.
		 */
		// TODO: keep track of the user's mode on the connection?
		[_delegate modeSet:param_0_data
						by:origin_data
				   session:self];
	} else if (!strcmp(event, "TOPIC")) {
		/*!
		 * The ‘topic’ event is triggered upon receipt of a TOPIC message, which
		 * means that someone on a channel with the client has changed the
		 * channel’s topic.
		 *
		 * \param origin The person who changes the channel topic.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the new topic.
		 */
		IRCClientChannel *channel = _channels[param_0_data];
		[channel topicSet:param_1_data
					   by:origin_data];
	} else if (!strcmp(event, "KICK")) {
		/*!
		 * The ‘kick’ event is triggered upon receipt of a KICK message, which
		 * means that someone on a channel with the client (or possibly the
		 * client itself!) has been forcibly ejected.
		 *
		 * \param origin The person who kicked the poor victim.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the nick of kicked person.
		 * \param params[2] Optional; contains the kick text.
		 */
		[self userKicked:param_1_data
			 fromChannel:param_0_data
					  by:origin_data
			  withReason:param_2_data];
	} else if (!strcmp(event, "ERROR")) {
		/*!
		 * The ‘error’ event is triggered upon receipt of an ERROR message, which
		 * (when sent to clients) usually means the client has been disconnected.
		 *
		 * \param origin the person, who generates the message.
		 * \param params optional, contains who knows what.
		 */
		[_delegate errorReceived:param_0_data
						 session:self];
	} else if (!strcmp(event, "INVITE")) {
		/*!
		 * The ‘invite’ event is triggered upon receipt of an INVITE message,
		 * which means that someone is permitting the client’s entry into a +i
		 * channel.
		 *
		 * \param origin The person who INVITEd you.
		 * \param params[0] Mandatory; contains your nick.
		 * \param params[1] Mandatory; contains the channel name you’re invited into.
		 *
		 * \sa irc_cmd_invite irc_cmd_chanmode_invite
		 */
		[_delegate invitedToChannel:param_1_data
								 by:origin_data
							session:self];
	} else if (!strcmp(event, "PRIVMSG")) {
		/*!
		 * The ‘privmsg’ event is triggered upon receipt of a PRIVMSG message
		 * which is addressed to one or more clients, which means that someone
		 * is sending the client a private message.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; contains your nick.
		 * \param params[1] Optional; contains the message text.
		 */
		[_delegate privateMessageReceived:param_1_data
								 fromUser:origin_data
								  session:self];
	} else if (!strcmp(event, "CHANMSG")) {
		/*!
		 * The ‘chanmsg’ event is triggered upon receipt of a PRIVMSG message
		 * to an entire channel, which means that someone on a channel with
		 * the client has said something aloud. Your own messages don’t trigger
		 * PRIVMSG event.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the message text.
		 */
		IRCClientChannel *channel = _channels[param_0_data];
		[channel messageSent:param_1_data
					  byUser:origin_data];
	} else if (!strcmp(event, "SERVMSG")) {
		/*!
		 * The ‘servmsg’ event is triggered upon receipt of a PRIVMSG message
		 * which is addressed to no one in particular, but it sent to the client
		 * anyway.
		 *
		 * \param origin The person who generated the message.
		 * \param params Optional; contains who knows what.
		 */
		[_delegate serverMessageReceivedFrom:origin_data
									  params:params_array
									 session:self];
	} else if (!strcmp(event, "PRIVNOTICE")) {
		/*!
		 * The ‘notice’ event is triggered upon receipt of a NOTICE message
		 * which means that someone has sent the client a public or private
		 * notice. According to RFC 1459, the only difference between NOTICE
		 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
		 * messages. Unfortunately, this rule is frequently violated by IRC
		 * servers itself - for example, NICKSERV messages require reply, and
		 * are NOTICEs.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; contains your nick.
		 * \param params[1] Optional; contains the message text.
		 */
		[_delegate privateNoticeReceived:param_1_data
								fromUser:origin_data
								 session:self];
	} else if (!strcmp(event, "CHANNOTICE")) {
		/*!
		 * The ‘notice’ event is triggered upon receipt of a NOTICE message
		 * which means that someone has sent the client a public or private
		 * notice. According to RFC 1459, the only difference between NOTICE
		 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
		 * messages. Unfortunately, this rule is frequently violated by IRC
		 * servers itself - for example, NICKSERV messages require reply, and
		 * are NOTICEs.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; contains the target channel name.
		 * \param params[1] Optional; contains the message text.
		 */
		IRCClientChannel *channel = _channels[param_0_data];
		[channel noticeSent:param_1_data
					 byUser:origin_data];
	} else if (!strcmp(event, "SERVNOTICE")) {
		/*!
		 * The ‘server_notice’ event is triggered upon receipt of a NOTICE
		 * message which means that the server has sent the client a notice.
		 * This notice is not necessarily addressed to the client’s nick
		 * (for example, AUTH notices, sent before the client’s nick is known).
		 * According to RFC 1459, the only difference between NOTICE
		 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
		 * messages. Unfortunately, this rule is frequently violated by IRC
		 * servers itself - for example, NICKSERV messages require reply, and
		 * are NOTICEs.
		 *
		 * \param origin The person who generated the message.
		 * \param params Optional; contains who knows what.
		 */
		[_delegate serverNoticeReceivedFrom:origin_data
									 params:params_array
									session:self];
	} else if (!strcmp(event, "CTCP_REQ")) {
		/*!
		 * The ‘ctcp’ event is triggered when the client receives the CTCP
		 * request. By default, the built-in CTCP request handler is used. The
		 * build-in handler automatically replies on most CTCP messages, so you
		 * will rarely need to override it.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; contains the complete CTCP message, including
		 *                  its arguments.
		 *
		 * Mirc generates PING, FINGER, VERSION, TIME and ACTION messages,
		 * check the source code of \c libirc_event_ctcp_internal function to
		 * see how to write your own CTCP request handler. Also you may find
		 * useful this question in FAQ: \ref faq4
		 */
		[self CTCPRequestReceived:param_0_data
						 fromUser:origin_data];
	} else if (!strcmp(event, "CTCP_REPL")) {
		/*!
		 * The ‘ctcp’ event is triggered when the client receives the CTCP reply.
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; the CTCP message itself with its arguments.
		 */
		if ([_delegate respondsToSelector:@selector(CTCPReplyReceived:fromUser:session:)]) {
			[_delegate CTCPReplyReceived:param_0_data
								fromUser:origin_data
								 session:self];
		}
	} else if (!strcmp(event, "CTCP_ACTION")) {
		/*!
		 * The ‘action’ event is triggered when the client receives the CTCP
		 * ACTION message. These messages usually looks like:\n
		 * \code
		 * [23:32:55] * Tim gonna sleep.
		 * \endcode
		 *
		 * \param origin The person who generated the message.
		 * \param params[0] Mandatory; the target of the message.
		 * \param params[1] Mandatory; the ACTION message.
		 */
		IRCClientChannel* channel = _channels[param_0_data];
		if (channel != nil) {
			// An action on a channel we’re on.
			[channel actionPerformed:param_1_data
							  byUser:origin_data];
		} else {
			// An action in a private message.
			[_delegate privateCTCPActionReceived:param_1_data
										fromUser:origin_data
										 session:self];
		}
	} else {
		/*!
		 * The ‘unknown’ event is triggered upon receipt of any number of
		 * unclassifiable miscellaneous messages, which aren’t handled by the
		 * library.
		 */
		if ([_delegate respondsToSelector:@selector(unknownEventReceived:from:params:session:)]) {
			[_delegate unknownEventReceived:[NSData dataFromCString:event]
									   from:origin_data
									 params:params_array
									session:self];
		}
	}
}

-(void) numericEventReceived:(NSUInteger)event
						from:(NSData *)origin
					  params:(NSArray *)params {
	if ([_delegate respondsToSelector:@selector(numericEventReceived:from:params:session:)]) {
		[_delegate numericEventReceived:event
								   from:origin
								 params:params
								session:self];
	}
}

/******************************************/
#pragma mark - Event handler helper methods
/******************************************/

-(void) nickChangedFrom:(NSData *)oldNick
					 to:(NSData *)newNick {
	NSData* oldNickOnly = [IRCClientSession nickFromNickUserHost:oldNick];
	
	if ([_nickname isEqualToData:oldNickOnly]) {
		_nickname = newNick;
		[_delegate nickChangedFrom:oldNickOnly
								to:newNick 
							   own:YES 
						   session:self];
	} else {
		[_delegate nickChangedFrom:oldNickOnly 
								to:newNick 
							   own:NO 
						   session:self];
	}
}

-(void) userJoined:(NSData *)nick
		   channel:(NSData *)channelName {
	NSData* nickOnly = [IRCClientSession nickFromNickUserHost:nick];
	
	if ([_nickname isEqualToData:nickOnly]) {
		// We just joined a channel; allocate an IRCClientChannel object and
		// add it to our channels list.
		
		IRCClientChannel* newChannel = [[IRCClientChannel alloc] initWithName:channelName 
																andIRCSession:_irc_session];
		_channels[channelName] = newChannel;
		[_delegate joinedNewChannel:newChannel 
							session:self];
	} else {
		// Someone joined a channel we’re on.
		
		IRCClientChannel* channel = _channels[channelName];
		[channel userJoined:nick];
	}
}

-(void) userParted:(NSData *)nick 
		   channel:(NSData *)channelName 
		withReason:(NSData *)reason {
	IRCClientChannel* channel = _channels[channelName];
	
	NSData* nickOnly = [IRCClientSession nickFromNickUserHost:nick];
	
	if ([_nickname isEqualToData:nickOnly]) {
		// We just left a channel; remove it from the channels dict.

		[_channels removeObjectForKey:channelName];
		[channel userParted:nick 
				 withReason:reason 
						 us:YES];
	} else {
		[channel userParted:nick 
				 withReason:reason 
						 us:NO];
	}
}

-(void) userKicked:(NSData *)nick 
	   fromChannel:(NSData *)channelName 
				by:(NSData *)byNick 
		withReason:(NSData *)reason {
	IRCClientChannel* channel = _channels[channelName];

	if (nick == nil) {
		// we got kicked from a channel we’re on :(
		[_channels removeObjectForKey:channelName];
		[channel userKicked:_nickname 
				 withReason:reason 
						 by:byNick 
						 us:YES];
	} else {
		// Someone else got booted from a channel we’re on.
		[channel userKicked:nick 
				 withReason:reason 
						 by:byNick 
						 us:NO];
	}
}

/*****************************************/
#pragma mark - CTCP request handler helper
/*****************************************/

-(void) CTCPRequestReceived:(NSData *)request 
				   fromUser:(NSData *)nick {
	NSData *nickOnly = [IRCClientSession nickFromNickUserHost:nick];

	if (!strncmp(request.terminatedCString, "PING", 4)) {
		[self ctcpReply:request
				 target:nickOnly];
	} else if (!strcmp(request.terminatedCString, "VERSION")) {
		const char *versionFormat = "VERSION %s";
		NSMutableData* versionReply = [NSMutableData dataWithLength:(strlen(versionFormat) + (_version.length - 2))];
		sprintf(versionReply.mutableBytes,
				versionFormat,
				_version.terminatedCString);

		[self ctcpReply:versionReply
				 target:nickOnly];
	} else if (!strcmp(request.terminatedCString, "FINGER")) {
		const char *fingerFormat = "FINGER %s (%s) Idle 0 seconds)";
		NSMutableData* fingerReply = [NSMutableData dataWithLength:(strlen(fingerFormat) + (_username.length - 2) + (_realname.length - 2))];
		sprintf(fingerReply.mutableBytes,
				fingerFormat,
				_username.terminatedCString,
				_realname.terminatedCString);

		[self ctcpReply:fingerReply
				 target:nickOnly];
	} else if (!strcmp(request.terminatedCString, "TIME")) {
		time_t current_time;
		char timestamp[40];
		struct tm *time_info;
		
		time(&current_time);
		time_info = localtime(&current_time);
		
		strftime(timestamp, 40, "TIME %a %b %e %H:%M:%S %Z %Y", time_info);
		
		[self ctcpReply:[NSData dataFromCString:timestamp]
				 target:nickOnly];
	} else {
		if ([_delegate respondsToSelector:@selector(CTCPRequestReceived:ofType:fromUser:session:)]) {
			NSRange rangeOfFirstSpace = [request rangeOfData:[NSData dataFromCString:" "]
													 options:(NSDataSearchOptions) 0
													   range:NSRangeMake(0, request.length)];

			NSRange rangeOfSecondSpace = (rangeOfFirstSpace.location != NSNotFound
										  ? [request rangeOfData:[NSData dataFromCString:" "]
														 options:(NSDataSearchOptions) 0
														   range:NSRangeMake(rangeOfFirstSpace.location + 1,
																			 request.length - (rangeOfFirstSpace.location + 1))]
										  : NSRangeMake(NSNotFound, 0));

			NSData *requestTypeData = (rangeOfFirstSpace.location != NSNotFound
									   ? [request subdataWithRange:NSRangeMake(0, rangeOfFirstSpace.location)]
									   : request);
			NSData *requestBodyData = (rangeOfSecondSpace.location != NSNotFound
									   ? [request subdataWithRange:NSRangeMake(rangeOfFirstSpace.location + 1,
																			   rangeOfSecondSpace.location - (rangeOfFirstSpace.location + 1))]
									   : nil);
			
			[_delegate CTCPRequestReceived:requestBodyData 
									ofType:requestTypeData 
								  fromUser:nick
								   session:self];
		}
	}
}

@end

/***********************************************/
#pragma mark - Callback function implementations
/***********************************************/

static void onEvent(irc_session_t *session,
					const char *event,
					const char *origin,
					const char **params,
					unsigned int count) {
	@autoreleasepool {
		[(__bridge IRCClientSession *) irc_get_ctx(session) ircEventReceived:event
																		from:origin
																  withParams:params
																	   count:count];
	}
}

/*!
 * The ‘numeric’ event is triggered upon receipt of any numeric response
 * from the server. There is a lot of such responses, see the full list
 * here: \ref rfcnumbers.
 *
 * \param session the session, which generates an event
 * \param event   the numeric code of the event. Useful in case you use a
 *                single event handler for several events simultaneously.
 * \param origin  the originator of the event. See the note below.
 * \param params  a list of event params. Depending on the event nature, it
 *                could have zero or more params. The actual number of params
 *                is specified in count. None of the params can be NULL, but
 *                ‘params’ pointer itself could be NULL for some events.
 * \param count   the total number of params supplied.
 */
static void onNumericEvent(irc_session_t *session,
						   unsigned int event, 
						   const char *origin,
						   const char **params, 
						   unsigned int count) {
	@autoreleasepool {
		[(__bridge IRCClientSession *) irc_get_ctx(session) numericEventReceived:event
																			from:[NSData dataFromCString:origin]
																		  params:[NSArray arrayOfCStringData:params
																									   count:count]];
	}
}

/*!
 * The ‘dcc chat’ event is triggered when someone requests a DCC CHAT from
 * you.
 *
 * \param session the session, which generates an event
 * \param nick    the person who requested DCC CHAT with you.
 * \param addr    the person's IP address in decimal-dot notation.
 * \param dccid   an id associated with this request. Use it in calls to
 *                irc_dcc_accept() or irc_dcc_decline().
 */
static void onDCCChatRequest(irc_session_t *session,
							 const char *nick,
							 const char *addr,
							 irc_dcc_t dccid) {
	// TODO: figure out what to do here???
}

/*!
 * The ‘dcc send’ event is triggered when someone wants to send a file
 * to you via DCC SEND request.
 *
 * \param session the session, which generates an event
 * \param nick    the person who requested DCC SEND to you.
 * \param addr    the person's IP address in decimal-dot notation.
 * \param filename the sent filename.
 * \param size    the filename size.
 * \param dccid   an id associated with this request. Use it in calls to
 *                irc_dcc_accept() or irc_dcc_decline().
 */
static void onDCCSendRequest(irc_session_t *session,
							 const char *nick,
							 const char *addr,
							 const char *filename,
							 size_t size,
							 irc_dcc_t dccid) {
	// TODO: figure out what to do here???
}
