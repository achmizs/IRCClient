/* 
 * Modified IRCClient Copyright 2015 Said Achmiz (www.saidachmiz.net)
 *
 * Original IRCClient Copyright (C) 2009 Nathan Ollerenshaw chrome@stupendous.net
 *
 * This library is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU Lesser General Public License as published by 
 * the Free Software Foundation; either version 2 of the License, or (at your 
 * option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public 
 * License for more details.
 */

#pragma mark Defines and includes

#define IRCCLIENTVERSION "1.0"

#import "IRCClientSession.h"
#import "IRCClientChannel.h"
#import "IRCClientChannel_Private.h"
#include "libircclient.h"
#include "string.h"

#pragma mark - Callback function declarations

static void onConnect(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onNick(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onQuit(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onJoinChannel(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onPartChannel(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onMode(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onUserMode(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onTopic(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onKick(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onChannelPrvmsg(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onPrivmsg(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onNotice(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onChannelNotice(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onInvite(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onCtcpRequest(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onCtcpReply(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onCtcpAction(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onUnknownEvent(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count);
static void onNumericEvent(irc_session_t *session, unsigned int event, const char *origin, const char **params, unsigned int count);

#pragma mark - IRCClientSession private category declaration

@interface IRCClientSession()
{
	irc_callbacks_t		callbacks;
	irc_session_t		*irc_session;
	NSThread			*thread;
	
	NSString			*version;
	NSString			*server;
	NSUInteger			port;
	NSData				*password;
	
	NSString			*nickname;
	NSString			*username;
	NSString			*realname;
	
	NSMutableDictionary *channels;
	NSStringEncoding	encoding;
}

@property (nonatomic, retain) NSMutableDictionary *channels;

@end

#pragma mark - IRCClientSession class implementation

@implementation IRCClientSession

#pragma mark - Property synthesis

@synthesize delegate;
@synthesize sessionID;
@synthesize version;
@synthesize server;
@synthesize port;
@synthesize password;
@synthesize nickname;
@synthesize username;
@synthesize realname;
@synthesize encoding;

#pragma mark - Custom accessors

-(NSDictionary*)channels
{
	NSDictionary* channelsCopy = [channels copy];
	return channelsCopy;
}

-(void)setChannels:(NSMutableDictionary *)newChannels
{
	channels = newChannels;
}

- (bool)connected
{
	return irc_is_connected(irc_session);
}

/************************************/
#pragma mark - Class methods
/************************************/

-(instancetype)init
{
    if ((self = [super init])) {
		callbacks.event_connect = onConnect;
		callbacks.event_nick = onNick;
		callbacks.event_quit = onQuit;
		callbacks.event_join = onJoinChannel;
		callbacks.event_part = onPartChannel;
		callbacks.event_mode = onMode;
		callbacks.event_umode = onUserMode;
		callbacks.event_topic = onTopic;
		callbacks.event_kick = onKick;
		callbacks.event_channel = onChannelPrvmsg;
		callbacks.event_privmsg = onPrivmsg;
		callbacks.event_notice = onNotice;
		callbacks.event_channel_notice = onChannelNotice;
		callbacks.event_invite = onInvite;
		callbacks.event_ctcp_req = onCtcpRequest;
		callbacks.event_ctcp_rep = onCtcpReply;
		callbacks.event_ctcp_action = onCtcpAction;
		callbacks.event_unknown = onUnknownEvent;
		callbacks.event_numeric = onNumericEvent;
		callbacks.event_dcc_chat_req = NULL;
		callbacks.event_dcc_send_req = NULL;
		
		irc_session = irc_create_session(&callbacks);
		
		if (!irc_session) {
			NSLog(@"Could not create irc_session.");
			return nil;
		}
		
		// Strip server info from nicks.
//		irc_option_set(irc_session, LIBIRC_OPTION_STRIPNICKS);
		
		irc_set_ctx(irc_session, (__bridge void *)(self));
		
		unsigned int high, low;
		irc_get_version (&high, &low);
		
		version = [NSString stringWithFormat:@"IRCClient Framework v%s (Nathan Ollerenshaw) - libirc v%d.%d (Georgy Yunaev)", IRCCLIENTVERSION, high, low];
		
		channels = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void)dealloc
{
	if (irc_is_connected(irc_session))
		NSLog(@"Warning: IRC Session is not disconnected on dealloc");
		
	irc_destroy_session(irc_session);
}

- (int)connect;
{
	unsigned short sPort = port;
		
	return irc_connect(irc_session, server.UTF8String, sPort, (password.length > 0 ? password.bytes : NULL), nickname.UTF8String, username.UTF8String, realname.UTF8String);
}

- (void)disconnect
{
	irc_disconnect(irc_session);
}

- (void)startThread
{
	@autoreleasepool {
		irc_run(irc_session);
	}
}

- (void)run
{
	if (thread) {
		NSLog(@"Thread already running!");
		return;
	}
	
	thread = [[NSThread alloc] initWithTarget:self selector:@selector(startThread) object:nil];
	[thread start];
}

/**************************/
#pragma mark - IRC commands
/**************************/

- (int)sendRaw:(NSData *)message
{
	return irc_send_raw(irc_session, message.bytes);
}

- (int)quit:(NSData *)reason
{
	return irc_cmd_quit(irc_session, reason.bytes);
}

- (int)join:(NSData *)channel key:(NSData *)key
{
	NSLog(@"Joining %@", channel);
	
	if (!key || !key.length > 0)
		return irc_cmd_join(irc_session, channel.bytes, NULL);

	return irc_cmd_join(irc_session, channel.bytes, key.bytes);
}

- (int)list:(NSData *)channel
{
	return irc_cmd_list(irc_session, channel.bytes);
}

- (int)userMode:(NSString *)mode
{
	return irc_cmd_user_mode(irc_session, mode.UTF8String);
}

- (int)nick:(NSString *)newnick
{
	return irc_cmd_nick(irc_session, newnick.UTF8String);
}

- (int)whois:(NSString *)nick
{
	return irc_cmd_whois(irc_session, nick.UTF8String);
}

- (int)message:(NSData *)message to:(NSString *)target
{
	return irc_cmd_msg(irc_session, target.UTF8String, message.bytes);
}

- (int)action:(NSData *)action to:(NSString *)target
{
	return irc_cmd_me(irc_session, target.UTF8String, action.bytes);
}

- (int)notice:(NSData *)notice to:(NSString *)target
{
	return irc_cmd_notice(irc_session, target.UTF8String, notice.bytes);
}

- (int)ctcpRequest:(NSData *)request target:(NSString *)target
{
	return irc_cmd_ctcp_request(irc_session, target.UTF8String, request.bytes);
}

- (int)ctcpReply:(NSData *)reply target:(NSString *)target
{
	return irc_cmd_ctcp_reply(irc_session, target.UTF8String, reply.bytes);
}

/****************************/
#pragma mark - Event handlers
/****************************/

- (void)connectionSucceeded
{
	[delegate connectionSucceeded];
}

- (void)nickChangedFrom:(NSString *)oldNick to:(NSString *)newNick
{
	if ([nickname isEqualToString:oldNick])
	{
		nickname = newNick;
		[delegate nickChangedFrom:oldNick to:newNick own:YES];
	}
	else
	{
		[delegate nickChangedFrom:oldNick to:newNick own:NO];
	}
}

- (void)userQuit:(NSString *)nick withReason:(NSData *)reason
{
	NSString* reasonString;
	
	if(reason)
	{
		reasonString = [[NSString alloc] initWithData:reason encoding:encoding];
	}
	
	[delegate userQuit:nick withReason:reasonString];
}

- (void)userJoined:(NSString *)nick channel:(NSData *)channelName
{
	NSString* nickOnly = getNickFromNickUserHost(nick);
	
	if ([nickname isEqualToString:nickOnly])
	{
		// We just joined a channel; allocate an IRCClientChannel object and send it
		// to the main thread.
		
		IRCClientChannel* newChannel = [[IRCClientChannel alloc] initWithName:channelName andIRCSession:irc_session];
		channels[channelName] = newChannel;
		[delegate joinedNewChannel:newChannel];
	}
	else
	{
		// Someone joined a channel we're on.
		
		IRCClientChannel* channel = channels[channelName];
		[channel userJoined:nick];
	}
}

- (void)userParted:(NSString *)nick channel:(NSData *)channelName withReason:(NSData *)reason
{
	IRCClientChannel* channel = channels[channelName];
	
	NSString* nickOnly = getNickFromNickUserHost(nick);
	
	if ([nickname isEqualToString:nickOnly])
	{
		// We just left a channel; remove it from the channels dict.
		[channels removeObjectForKey:channelName];
		[channel userParted:nick withReason:reason us:YES];
	}
	else
	{
		[channel userParted:nick withReason:reason us:NO];
	}
}

- (void)modeSet:(NSString* )mode withParams:(NSString *)params forChannel:(NSData *)channelName by:(NSString *)nick
{
	IRCClientChannel *channel = channels[channelName];
	
	[channel modeSet:mode withParams:params by:nick];
}

- (void)modeSet:(NSString *)mode by:(NSString *)nick
{
	[delegate modeSet:mode by:nick];
}

- (void)topicSet:(NSData *)newTopic forChannel:(NSData *)channelName by:(NSString *)nick
{
	IRCClientChannel *channel = channels[channelName];
	
	[channel topicSet:newTopic by:nick];
}

- (void)userKicked:(NSString *)nick fromChannel:(NSData *)channelName by:(NSString *)byNick withReason:(NSData *)reason
{
	IRCClientChannel* channel = channels[channelName];

	if (nick == nil)
	{
		// we got kicked from a channel we're on
		[channels removeObjectForKey:channelName];
		[channel userKicked:nickname withReason:reason by:byNick us:YES];
	}
	else
	{
		// someone else got booted from a channel we're on
		[channel userKicked:nick withReason:reason by:byNick us:NO];
	}
}

- (void)messageSent:(NSData *)message toChannel:(NSData *)channelName byUser:(NSString *)nick
{
	IRCClientChannel *channel = channels[channelName];
	
	[channel messageSent:message byUser:nick];
}

- (void)privateMessageReceived:(NSData *)message fromUser:(NSString *)nick
{
	NSString* messageString = [[NSString alloc] initWithData:message encoding:encoding];
	
	[delegate privateMessageReceived:messageString fromUser:nick];
}

- (void)noticeSent:(NSData *)notice toChannel:(NSData *)channelName byUser:(NSString *)nick
{
	IRCClientChannel *channel = channels[channelName];
	
	[channel noticeSent:notice byUser:nick];
}

- (void)privateNoticeReceived:(NSData *)notice fromUser:(NSString *)nick
{
	NSString* noticeString = [[NSString alloc] initWithData:notice encoding:encoding];
	
	[delegate privateNoticeReceived:noticeString fromUser:nick];
}

- (void)invitedToChannel:(NSData *)channelName by:(NSString *)nick
{
	[delegate invitedToChannel:channelName by:nick];
}

- (void)CTCPRequestReceived:(NSData *)request fromUser:(NSString *)nick
{
	const char* the_nick = getNickFromNickUserHost(nick).UTF8String;
	const char* the_request = request.bytes;
	
	if (strstr(the_request, "PING") == the_request)
	{
		irc_cmd_ctcp_reply(irc_session, the_nick, the_request);
	}
	else if (!strcmp (the_request, "VERSION"))
	{
		irc_cmd_ctcp_reply (irc_session, the_nick, [NSString stringWithFormat:@"VERSION %@", version].UTF8String);
	}
	else if (!strcmp (the_request, "FINGER"))
	{
		irc_cmd_ctcp_reply (irc_session, the_nick, [NSString stringWithFormat:@"FINGER %@ (%@) Idle 0 seconds", username, realname].UTF8String);
	}
	else if (!strcmp (the_request, "TIME"))
	{
		irc_cmd_ctcp_reply(irc_session, the_nick, [[NSDate dateWithTimeIntervalSinceNow:0] descriptionWithCalendarFormat:@"TIME %a %b %e %H:%M:%S %Z %Y" timeZone:nil locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]].UTF8String);
	}
	else
	{
		if ([delegate respondsToSelector:@selector(CTCPRequestReceived:ofType:fromUser:)])
		{
			char* request_string = malloc(request.length);
			[request getBytes:request_string length:request.length];
			
			char* request_type = strtok(request_string, " ");
			char* request_body = strtok(NULL, " " );
			
			[delegate CTCPRequestReceived:[NSData dataWithBytes:request_body length:strlen(request_body)+1] ofType:[NSData dataWithBytes:request_type length:strlen(request_type)+1] fromUser:nick];
		}
	}
}

- (void)CTCPReplyReceived:(NSData *)reply fromUser:(NSString *)nick
{
	[delegate CTCPReplyReceived:reply fromUser:nick];
}

- (void)CTCPActionPerformed:(NSData *)action byUser:(NSString *)nick atTarget:(NSData *)target
{
	IRCClientChannel* channel = channels[target];
	
	if(channel != nil)
	{
		// An action on a channel we're on
		[channel actionPerformed:action byUser:nick];
	}
	else
	{
		// An action in a private message
		NSString* actionString = [[NSString alloc] initWithData:action encoding:encoding];
		[delegate privateCTCPActionReceived:actionString fromUser:nick];
	}
}

- (void)unknownEventReceived:(NSData *)event from:(NSString *)origin params:(NSArray *)params
{
	[delegate unknownEventReceived:event from:origin params:params];
}

-(void)numericEventReceived:(NSUInteger)event from:(NSString *)origin params:(NSArray *)params
{
	[delegate numericEventReceived:event from:origin params:params];
}

@end

#pragma mark - Useful helper functions

NSString* getNickFromNickUserHost(NSString *nuh)
{
	NSArray *nuhArray = [nuh componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"!@"]];
	
	if (nuhArray.count == 3)
	{
		return [NSString stringWithString:nuhArray[0]];
	}
	else
	{
		return [NSString stringWithString:nuh];
	}
}

NSString* getUserFromNickUserHost(NSString *nuh)
{
	NSArray *nuhArray = [nuh componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"!@"]];
	
	if (nuhArray.count == 3)
	{
		return [NSString stringWithString:nuhArray[1]];
	}
	else
	{
		return nil;
	}
}

NSString* getHostFromNickUserHost(NSString *nuh)
{
	NSArray *nuhArray = [nuh componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"!@"]];
	
	if (nuhArray.count == 3)
	{
		return [NSString stringWithString:nuhArray[2]];
	}
	else
	{
		return nil;
	}
}

/***********************************************/
#pragma mark - Callback function implementations
/***********************************************/

/*!
 * The "on_connect" event is triggered when the client successfully 
 * connects to the server, and could send commands to the server.
 * No extra params supplied; \a params is 0.
 */
static void onConnect(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession* clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	
	[clientSession connectionSucceeded];
}

/*!
 * The "nick" event is triggered when the client receives a NICK message,
 * meaning that someone (including you) on a channel with the client has 
 * changed their nickname. 
 *
 * \param origin the person, who changes the nick. Note that it can be you!
 * \param params[0] mandatory, contains the new nick.
 */
static void onNick(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession* clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *oldNick = @(origin);
	NSString *newNick = @(params[0]);
	
	[clientSession nickChangedFrom:oldNick to:newNick];
}

/*!
 * The "quit" event is triggered upon receipt of a QUIT message, which
 * means that someone on a channel with the client has disconnected.
 *
 * \param origin the person, who is disconnected
 * \param params[0] optional, contains the reason message (user-specified).
 */
static void onQuit(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	
	NSString *nick = @(origin);
	NSData *reason = nil;
	if(count > 0)
	{
		reason = [[NSData alloc] initWithBytes:params[0] length:strlen(params[0])];
	}

	[clientSession userQuit:nick withReason:reason];
}

/*!
 * The "join" event is triggered upon receipt of a JOIN message, which
 * means that someone has entered a channel that the client is on.
 *
 * \param origin the person, who joins the channel. By comparing it with 
 *               your own nickname, you can check whether your JOIN 
 *               command succeed.
 * \param params[0] mandatory, contains the channel name.
 */
static void onJoinChannel(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession* clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	
	[clientSession userJoined:nick channel:channelName];
}

/*!
 * The "part" event is triggered upon receipt of a PART message, which
 * means that someone has left a channel that the client is on.
 *
 * \param origin the person, who leaves the channel. By comparing it with 
 *               your own nickname, you can check whether your PART 
 *               command succeed.
 * \param params[0] mandatory, contains the channel name.
 * \param params[1] optional, contains the reason message (user-defined).
 */
static void onPartChannel(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSData *reason = nil;
	
	if (count > 1)
	{
		reason = [NSData dataWithBytes:params[1] length:strlen(params[1])+1];
	}
	
	[clientSession userParted:nick channel:channelName withReason:reason];
}

/*!
 * The "mode" event is triggered upon receipt of a channel MODE message,
 * which means that someone on a channel with the client has changed the
 * channel's parameters.
 *
 * \param origin the person, who changed the channel mode.
 * \param params[0] mandatory, contains the channel name.
 * \param params[1] mandatory, contains the changed channel mode, like 
 *        '+t', '-i' and so on.
 * \param params[2] optional, contains the mode argument (for example, a
 *      key for +k mode, or user who got the channel operator status for 
 *      +o mode)
 */
static void onMode(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSString *mode = @(params[1]);
	NSString *modeParams = nil;
	
	if (count > 2)
	{
		modeParams = @(params[2]);
	}
	
	[clientSession modeSet:mode withParams:modeParams forChannel:channelName by:nick];
}

/*!
 * The "umode" event is triggered upon receipt of a user MODE message, 
 * which means that your user mode has been changed.
 *
 * \param origin the person, who changed the channel mode.
 * \param params[0] mandatory, contains the user changed mode, like 
 *        '+t', '-i' and so on.
 */
static void onUserMode(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString* nick = @(origin);
	NSString *mode = @(params[0]);
	
	[clientSession modeSet:mode by:nick];
}

/*!
 * The "topic" event is triggered upon receipt of a TOPIC message, which
 * means that someone on a channel with the client has changed the 
 * channel's topic.
 *
 * \param origin the person, who changes the channel topic.
 * \param params[0] mandatory, contains the channel name.
 * \param params[1] optional, contains the new topic.
 */
static void onTopic(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSData *topic = nil;
	
	if (count > 1)
	{
		topic = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	}
	
	[clientSession topicSet:topic forChannel:channelName by:nick];
}

/*!
 * The "kick" event is triggered upon receipt of a KICK message, which
 * means that someone on a channel with the client (or possibly the
 * client itself!) has been forcibly ejected.
 *
 * \param origin the person, who kicked the poor.
 * \param params[0] mandatory, contains the channel name.
 * \param params[1] optional, contains the nick of kicked person.
 * \param params[2] optional, contains the kick text
 */
static void onKick(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *byNick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSString *nick = nil;
	NSData *reason = nil;
	
	if (count > 1)
	{
		nick = @(params[1]);
	}
	
	if (count > 2)
	{
		reason = [NSData dataWithBytes:params[2] length:strlen(params[2])];
	}
	
	[clientSession userKicked:nick fromChannel:channelName by:byNick withReason:reason];
}

/*!
 * The "channel" event is triggered upon receipt of a PRIVMSG message
 * to an entire channel, which means that someone on a channel with
 * the client has said something aloud. Your own messages don't trigger
 * PRIVMSG event.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, contains the channel name.
 * \param params[1] optional, contains the message text
 */
static void onChannelPrvmsg(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSData *message = nil;
	
	if (count > 1)
	{
		message = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	}

	NSLog(@"onChannelPrvmsg");
	[clientSession messageSent:message toChannel:channelName byUser:nick];
}

/*!
 * The "privmsg" event is triggered upon receipt of a PRIVMSG message
 * which is addressed to one or more clients, which means that someone
 * is sending the client a private message.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, contains your nick.
 * \param params[1] optional, contains the message text
 */
static void onPrivmsg(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *message = nil;

	if (count > 1)
	{
		message = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	}
	
	[clientSession privateMessageReceived:message fromUser:nick];
}

/*!
 * The "notice" event is triggered upon receipt of a NOTICE message
 * which means that someone has sent the client a public or private
 * notice. According to RFC 1459, the only difference between NOTICE 
 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
 * messages. Unfortunately, this rule is frequently violated by IRC 
 * servers itself - for example, NICKSERV messages require reply, and 
 * are NOTICEs.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, contains your nick.
 * \param params[1] optional, contains the message text
 */
static void onNotice(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *notice = nil;
	
	if (count > 1)
	{
		notice = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	}
	
	[clientSession privateNoticeReceived:notice fromUser:nick];
}

/*!
 * The "notice" event is triggered upon receipt of a NOTICE message
 * which means that someone has sent the client a public or private
 * notice. According to RFC 1459, the only difference between NOTICE
 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
 * messages. Unfortunately, this rule is frequently violated by IRC
 * servers itself - for example, NICKSERV messages require reply, and
 * are NOTICEs.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, contains the target channel name.
 * \param params[1] optional, contains the message text.
 */
static void onChannelNotice(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSData *notice = nil;
	
	if (count > 1)
	{
		notice = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	}

	[clientSession noticeSent:notice toChannel:channelName byUser:nick];
}

/*!
 * The "invite" event is triggered upon receipt of an INVITE message,
 * which means that someone is permitting the client's entry into a +i
 * channel.
 *
 * \param origin the person, who INVITEs you.
 * \param params[0] mandatory, contains your nick.
 * \param params[1] mandatory, contains the channel name you're invited into.
 *
 * \sa irc_cmd_invite irc_cmd_chanmode_invite
 */
static void onInvite(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData *channelName = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	
	[clientSession invitedToChannel:channelName by:nick];
}

/*!
 * The "ctcp" event is triggered when the client receives the CTCP 
 * request. By default, the built-in CTCP request handler is used. The 
 * build-in handler automatically replies on most CTCP messages, so you
 * will rarely need to override it.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, the complete CTCP message, including its 
 *                  arguments.
 * 
 * Mirc generates PING, FINGER, VERSION, TIME and ACTION messages,
 * check the source code of \c libirc_event_ctcp_internal function to 
 * see how to write your own CTCP request handler. Also you may find 
 * useful this question in FAQ: \ref faq4
 */
static void onCtcpRequest(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSString *nick = @(origin);
	NSData* request = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	
	[clientSession CTCPRequestReceived:request fromUser:nick];
}

/*!
 * The "ctcp" event is triggered when the client receives the CTCP reply.
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, the CTCP message itself with its arguments.
 */
static void onCtcpReply(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	
	NSString *nick = @(origin);
	NSData *reply = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	
	[clientSession CTCPReplyReceived:reply fromUser:nick];
}

/*!
 * The "action" event is triggered when the client receives the CTCP 
 * ACTION message. These messages usually looks like:\n
 * \code
 * [23:32:55] * Tim gonna sleep.
 * \endcode
 *
 * \param origin the person, who generates the message.
 * \param params[0] mandatory, the target of the message.
 * \param params[1] mandatory, the ACTION message.
 */
static void onCtcpAction(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	
	NSString *nick = @(origin);
	NSData *target = [NSData dataWithBytes:params[0] length:strlen(params[0])];
	NSData *action = [NSData dataWithBytes:params[1] length:strlen(params[1])];
	
	[clientSession CTCPActionPerformed:action byUser:nick atTarget:target];
}

/*!
 * The "unknown" event is triggered upon receipt of any number of 
 * unclassifiable miscellaneous messages, which aren't handled by the
 * library.
 */
static void onUnknownEvent(irc_session_t *session, const char *event, const char *origin, const char **params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSData *eventString = [NSData dataWithBytes:event length:strlen(event)];
	NSString *sender = nil;
	
	if (origin != NULL)
		sender = @(origin);
	
	NSMutableArray *paramsArray = [[NSMutableArray alloc] init];
	
	for (unsigned int i = 0; i < count; i++)
		[paramsArray addObject:[NSData dataWithBytes:params[i] length:strlen(params[i])]];
	
	[clientSession unknownEventReceived:eventString from:sender params:[paramsArray copy]];
}

/*!
 * The "numeric" event is triggered upon receipt of any numeric response
 * from the server. There is a lot of such responses, see the full list
 * here: \ref rfcnumbers.
 *
 * See the params in ::irc_eventcode_callback_t specification.
 */
static void onNumericEvent(irc_session_t * session, unsigned int event, const char * origin, const char ** params, unsigned int count)
{
	IRCClientSession *clientSession = (__bridge IRCClientSession *) irc_get_ctx(session);
	NSUInteger eventNumber = event;
	NSString *sender = @(origin);
	
	NSMutableArray *paramsArray = [[NSMutableArray alloc] init];
	
	for (unsigned int i = 0; i < count; i++)
		[paramsArray addObject:[NSData dataWithBytes:params[i] length:strlen(params[i])]];
	
	[clientSession numericEventReceived:eventNumber from:sender params:[paramsArray copy]];
}
