//
//	IRCClientChannel.m
//	IRCClient
/*
 * Copyright 2015 Said Achmiz (www.saidachmiz.net)
 *
 * Copyright (C) 2009 Nathan Ollerenshaw chrome@stupendous.net
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

#import "IRCClientChannel.h"
#import "IRCClientChannel_Private.h"
#import "NSData+SA_NSDataExtensions.h"

/*********************************************/
#pragma mark IRCClientChannel private category
/*********************************************/

@interface IRCClientChannel()
{
	irc_session_t		*_irc_session;

	NSMutableArray		*_nicks;
}

@property (readwrite) NSData *topic;
@property (readwrite) NSData *modes;
@property (readwrite) NSMutableArray *nicks;

@end

/***************************************************/
#pragma mark - IRCClientChannel class implementation
/***************************************************/

@implementation IRCClientChannel

/********************************/
#pragma mark - Property synthesis
/********************************/

@synthesize delegate = _delegate;
@synthesize name = _name;
@synthesize encoding = _encoding;
@synthesize topic = _topic;
@synthesize modes = _modes;

/******************************/
#pragma mark - Custom accessors
/******************************/

-(NSArray *)nicks
{
	NSArray* nicksCopy = [_nicks copy];
	return nicksCopy;
}

-(void)setNicks:(NSArray *)nicks
{
	_nicks = [nicks mutableCopy];
}

/**************************/
#pragma mark - Initializers
/**************************/

-(instancetype)initWithName:(NSData *)name andIRCSession:(irc_session_t *)irc_session
{
    if ((self = [super init]))
	{
		_irc_session = irc_session;

		_name = name;
		_encoding = NSUTF8StringEncoding;
		_topic = [NSData dataWithBytes:"\0" length:1];
		_modes = [NSData dataWithBytes:"\0" length:1];
	}
	
	return self;
}

/**************************/
#pragma mark - IRC commands
/**************************/

- (int)part
{
	return irc_cmd_part(_irc_session, _name.SA_terminatedCString);
}

- (int)invite:(NSData *)nick
{
	return irc_cmd_invite(_irc_session, nick.SA_terminatedCString, _name.SA_terminatedCString);
}

- (int)refreshNames
{
	return irc_cmd_names(_irc_session, _name.SA_terminatedCString);
}

- (void)setChannelTopic:(NSData *)newTopic
{	
	irc_cmd_topic(_irc_session, _name.SA_terminatedCString, newTopic.SA_terminatedCString);
}

- (int)setMode:(NSData *)mode params:(NSData *)params
{
	if(params != nil)
	{
		NSMutableData *fullModeString = (params != nil) ? [NSMutableData dataWithLength:mode.length + 1 + params.length] : [NSMutableData dataWithLength:mode.length];
		sprintf(fullModeString.mutableBytes, "%s %s", mode.bytes, params.bytes);
		
		return irc_cmd_channel_mode(_irc_session, _name.SA_terminatedCString, fullModeString.SA_terminatedCString);
	}
	else
	{
		return irc_cmd_channel_mode(_irc_session, _name.SA_terminatedCString, mode.SA_terminatedCString);
	}
}

- (int)message:(NSData *)message
{
	return irc_cmd_msg(_irc_session, _name.SA_terminatedCString, message.SA_terminatedCString);
}

- (int)action:(NSData *)action
{
	return irc_cmd_me(_irc_session, _name.SA_terminatedCString, action.SA_terminatedCString);
}

- (int)notice:(NSData *)notice
{
	return irc_cmd_notice(_irc_session, _name.SA_terminatedCString, notice.SA_terminatedCString);
}

- (int)kick:(NSData *)nick reason:(NSData *)reason
{
	return irc_cmd_kick(_irc_session, nick.SA_terminatedCString, _name.SA_terminatedCString, reason.SA_terminatedCString);
}

- (int)ctcpRequest:(NSData *)request
{
	return irc_cmd_ctcp_request(_irc_session, _name.SA_terminatedCString, request.SA_terminatedCString);
}

/****************************/
#pragma mark - Event handlers
/****************************/

- (void)userJoined:(NSData *)nick
{
	[_delegate userJoined:nick];
}

- (void)userParted:(NSData *)nick withReason:(NSData *)reason us:(BOOL)wasItUs
{
	[_delegate userParted:nick withReason:reason us:wasItUs];
}

- (void)modeSet:(NSData *)mode withParams:(NSData *)params by:(NSData *)nick
{
	[_delegate modeSet:mode withParams:params by:nick];
}

- (void)topicSet:(NSData *)topic by:(NSData *)nick
{
	_topic = topic;
	
	[_delegate topicSet:topic by:nick];
}

- (void)userKicked:(NSData *)nick withReason:(NSData *)reason by:(NSData *)byNick us:(BOOL)wasItUs
{
	[_delegate userKicked:nick withReason:reason by:byNick us:wasItUs];
}

- (void)messageSent:(NSData *)message byUser:(NSData *)nick
{
	[_delegate messageSent:message byUser:nick];
}

- (void)noticeSent:(NSData *)notice byUser:(NSData *)nick
{
	[_delegate noticeSent:notice byUser:nick];
}

- (void)actionPerformed:(NSData *)action byUser:(NSData *)nick
{
	[_delegate actionPerformed:action byUser:nick];
}

@end
