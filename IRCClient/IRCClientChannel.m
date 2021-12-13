//
//	IRCClientChannel.m
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import "IRCClientChannel.h"
#import "IRCClientChannel_Private.h"
#import "NSData+SA_NSDataExtensions.h"

/********************************************/
#pragma mark IRCClientChannel class extension
/********************************************/

@interface IRCClientChannel() {
	irc_session_t	*_irc_session;

	// TODO: actually keep track of nicks! Use RPL_NAMREPLY and so on...
	// (see refreshNames...)
	NSMutableArray	*_nicks;
}

@end

/***************************************************/
#pragma mark - IRCClientChannel class implementation
/***************************************************/

@implementation IRCClientChannel

/************************/
#pragma mark - Properties
/************************/

-(NSArray *) nicks {
	return [_nicks copy];
}

-(IRCClientSession *) session {
	return (__bridge IRCClientSession *) irc_get_ctx(_irc_session);
}

/********************************************/
#pragma mark - Initializers & factory methods
/********************************************/

+(instancetype) channel {
	return [self new];
}

/**************************/
#pragma mark - Initializers
/**************************/

-(instancetype) initWithName:(NSData *)name 
			   andIRCSession:(irc_session_t *)irc_session {
	if (!(self = [super init]))
		return nil;

	_irc_session = irc_session;

	_name = name;
	_encoding = NSUTF8StringEncoding;
	_topic = [NSData dataWithBlankCString];
	_modes = [NSData dataWithBlankCString];
	_nicks = [NSMutableArray array];

	return self;
}

/**************************/
#pragma mark - IRC commands
/**************************/

-(int) part {
	return irc_send_raw(_irc_session,
						"PART %s",
						_name.terminatedCString);
}

-(int) invite:(NSData *)nick {
	if (!nick || nick.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"INVITE %s %s",
						nick.terminatedCString,
						_name.terminatedCString);
}

-(int) refreshNames {
	return irc_send_raw(_irc_session,
						"NAMES %s",
						_name.terminatedCString);
}

-(int) setChannelTopic:(NSData *)newTopic {
	if (newTopic)
		return irc_send_raw(_irc_session,
							"TOPIC %s :%s",
							_name.terminatedCString,
							newTopic.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"TOPIC %s",
							_name.terminatedCString);
}

-(int) setMode:(NSData *)mode 
		params:(NSData *)params {
	if (mode != nil) {
		NSMutableData *fullModeString = ((params != nil) ?
										 [NSMutableData dataWithLength:mode.length + 1 + params.length] :
										 [NSMutableData dataWithLength:mode.length + 1]);
		sprintf(fullModeString.mutableBytes, 
				"%s %s", 
				mode.terminatedCString,
				params.terminatedCString);
		
		return irc_send_raw(_irc_session,
							"MODE %s %s",
							_name.terminatedCString,
							fullModeString.terminatedCString);
	} else {
		return irc_send_raw(_irc_session,
							"MODE %s",
							_name.terminatedCString);
	}
}

-(int) message:(NSData *)message {
	if (!message || message.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :%s",
						_name.terminatedCString,
//						irc_color_convert_to_mirc(message.terminatedCString));
						[self.session colorConvertToMIRC:message].terminatedCString);
}

-(int) action:(NSData *)action {
	if (!action || action.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :\x01" "ACTION %s\x01",
						_name.terminatedCString,
//						irc_color_convert_to_mirc(action.terminatedCString));
						[self.session colorConvertToMIRC:action].terminatedCString);
}

-(int) notice:(NSData *)notice {
	if (!notice || notice.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"NOTICE %s :%s",
						_name.terminatedCString,
						notice.terminatedCString);
}

-(int) kick:(NSData *)nick 
	 reason:(NSData *)reason {
	if (!nick || nick.length == 0)
		return LIBIRC_ERR_STATE;

	if (reason)
		return irc_send_raw(_irc_session,
							"KICK %s %s :%s",
							_name.terminatedCString,
							nick.terminatedCString,
							reason.terminatedCString);
	else
		return irc_send_raw(_irc_session,
							"KICK %s %s",
							_name.terminatedCString,
							nick.terminatedCString);
}

-(int) ctcpRequest:(NSData *)request {
	if (!request || request.length == 0)
		return LIBIRC_ERR_STATE;

	return irc_send_raw(_irc_session,
						"PRIVMSG %s :\x01%s\x01",
						_name.terminatedCString,
						request.terminatedCString);
}

/****************************/
#pragma mark - Event handlers
/****************************/

-(void) userJoined:(NSData *)nick {
	[_nicks addObject:nick];

	[_delegate userJoined:nick 
				  channel:self];
}

-(void) userParted:(NSData *)nick 
		withReason:(NSData *)reason 
				us:(BOOL)wasItUs {
	if (!wasItUs) {
		[_nicks removeObject:nick];
	} else {
		// NOTE: When the channel object receives this message, and wasItUs
		// is true, its session has already removed the channel from its list
		// of channels.
		// TODO: but what if it was us? the delegate handles it...? or do we do
		// something here?
	}

	[_delegate userParted:nick 
				  channel:self 
			   withReason:reason 
					   us:wasItUs];
}

-(void) modeSet:(NSData *)mode 
	 withParams:(NSData *)params 
			 by:(NSData *)nick {
	// TODO: actually update the mode based on this event ... figure out what
	// mode set event returns?
//	_modes =

	[_delegate modeSet:mode 
			forChannel:self 
			withParams:params 
					by:nick];
}

-(void) topicSet:(NSData *)topic 
			  by:(NSData *)nick {
	_topic = topic;
	
	[_delegate topicSet:topic 
			 forChannel:self 
					 by:nick];
}

-(void) userKicked:(NSData *)nick 
		withReason:(NSData *)reason 
				by:(NSData *)byNick
				us:(BOOL)wasItUs {
	if (!wasItUs) {
		[_nicks removeObject:nick];
	} else {
		// NOTE: When the channel object receives this message, and wasItUs
		// is true, its session has already removed the channel from its list
		// of channels.
		// TODO: but what if it was us? the delegate handles it...? or do we do
		// something here?
	}

	[_delegate userKicked:nick
			  fromChannel:self 
			   withReason:reason
					   by:byNick 
					   us:wasItUs];
}

-(void) messageSent:(NSData *)message 
			 byUser:(NSData *)nick {
	[_delegate messageSent:message
					byUser:nick 
				 onChannel:self];
}

-(void) noticeSent:(NSData *)notice 
			byUser:(NSData *)nick {
	[_delegate noticeSent:notice 
				   byUser:nick 
				onChannel:self];
}

-(void) actionPerformed:(NSData *)action 
				 byUser:(NSData *)nick {
	[_delegate actionPerformed:action 
						byUser:nick 
					 onChannel:self];
}

@end
