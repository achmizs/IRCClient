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
			   andIRCSession:(IRCClientSession *)session {
	if (!(self = [super init]))
		return nil;

	_session = session;

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
	[_session sendRaw:[NSData dataWithFormat:"PART %@", _name, nil]];

	return 0;
}

-(int) invite:(NSData *)nick {
	if (!nick || nick.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[_session sendRaw:[NSData dataWithFormat:"INVITE %@ %@", nick, _name, nil]];

	return 0;
}

-(int) refreshNames {
	[_session sendRaw:[NSData dataWithFormat:"NAMES %@", _name, nil]];

	return 0;
}

-(int) channelTopic:(NSData *)newTopic {
	if (newTopic)
		[_session sendRaw:[NSData dataWithFormat:"TOPIC %@ :%@", _name, newTopic, nil]];
	else
		[_session sendRaw:[NSData dataWithFormat:"TOPIC %@", _name, nil]];

	return 0;
}

-(int) channelMode:(NSData *)mode
			params:(NSData *)params {
	if (mode != nil) {
		if (params != nil)
			[_session sendRaw:[NSData dataWithFormat:"MODE %@ %@ %@", _name, mode, params, nil]];
		else
			[_session sendRaw:[NSData dataWithFormat:"MODE %@ %@", _name, mode, nil]];
	} else {
		[_session sendRaw:[NSData dataWithFormat:"MODE %@", _name, nil]];
	}

	return 0;
}

-(int) message:(NSData *)message {
	if (!message || message.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[_session sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :%@", _name, [self.session colorConvertToMIRC:message], nil]];

	return 0;
}

-(int) action:(NSData *)action {
	if (!action || action.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[_session sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :\x01" "ACTION %@\x01", _name, [self.session colorConvertToMIRC:action], nil]];

	return 0;
}

-(int) notice:(NSData *)notice {
	if (!notice || notice.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[_session sendRaw:[NSData dataWithFormat:"NOTICE %@ :%@", _name, notice, nil]];

	return 0;
}

-(int) kick:(NSData *)nick 
	 reason:(NSData *)reason {
	if (!nick || nick.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	if (reason)
		[_session sendRaw:[NSData dataWithFormat:"KICK %@ %@ :%@", _name, nick, reason, nil]];
	else
		[_session sendRaw:[NSData dataWithFormat:"KICK %@ %@", _name, nick, nil]];

	return 0;
}

-(int) ctcpRequest:(NSData *)request {
	if (!request || request.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[_session sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :\x01%@\x01", _name, request, nil]];

	return 0;
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
