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
@property (readwrite) NSString *modes;
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
		_topic = [NSData dataWithBytes:@"".UTF8String length:1];
		_modes = @"";
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

- (int)invite:(NSString *)nick
{
	return irc_cmd_invite(_irc_session, nick.UTF8String, _name.SA_terminatedCString);
}

- (int)refreshNames
{
	return irc_cmd_names(_irc_session, _name.SA_terminatedCString);
}

- (void)setChannelTopic:(NSString *)newTopic
{	
	irc_cmd_topic(_irc_session, _name.SA_terminatedCString, [newTopic cStringUsingEncoding:_encoding]);
}

- (int)setMode:(NSString *)mode params:(NSString *)params
{
	NSMutableString* modeString = [mode mutableCopy];
	
	if(params != nil && params.length > 0)
		[modeString appendFormat:@" %@", params];
	
	return irc_cmd_channel_mode(_irc_session, _name.SA_terminatedCString, modeString.UTF8String);
}

- (int)message:(NSString *)message
{
	return irc_cmd_msg(_irc_session, _name.SA_terminatedCString, [message cStringUsingEncoding:_encoding]);
}

- (int)action:(NSString *)action
{
	return irc_cmd_me(_irc_session, _name.SA_terminatedCString, [action cStringUsingEncoding:_encoding]);
}

- (int)notice:(NSString *)notice
{
	return irc_cmd_notice(_irc_session, _name.SA_terminatedCString, [notice cStringUsingEncoding:_encoding]);
}

- (int)kick:(NSString *)nick reason:(NSString *)reason
{
	return irc_cmd_kick(_irc_session, nick.UTF8String, _name.SA_terminatedCString, [reason cStringUsingEncoding:_encoding]);
}

- (int)ctcpRequest:(NSData *)request
{
	return irc_cmd_ctcp_request(_irc_session, _name.SA_terminatedCString, request.SA_terminatedCString);
}

/****************************/
#pragma mark - Event handlers
/****************************/

- (void)userJoined:(NSString *)nick
{
	[_delegate userJoined:nick];
}

- (void)userParted:(NSString *)nick withReason:(NSData *)reason us:(BOOL)wasItUs
{
	NSString* reasonString = [NSString stringWithCString:reason.SA_terminatedCString encoding:_encoding];
	[_delegate userParted:nick withReason:reasonString us:wasItUs];
}

- (void)modeSet:(NSString *)mode withParams:(NSString *)params by:(NSString *)nick
{
	[_delegate modeSet:mode withParams:params by:nick];
}

- (void)topicSet:(NSData *)topic by:(NSString *)nick
{
	_topic = topic;
	
	NSString* topicString = [NSString stringWithCString:topic.SA_terminatedCString encoding:_encoding];
	[_delegate topicSet:topicString by:nick];
}

- (void)userKicked:(NSString *)nick withReason:(NSData *)reason by:(NSString *)byNick us:(BOOL)wasItUs
{
	NSString* reasonString = [NSString stringWithCString:reason.SA_terminatedCString encoding:_encoding];
	[_delegate userKicked:nick withReason:reasonString by:byNick us:wasItUs];
}

- (void)messageSent:(NSData *)message byUser:(NSString *)nick
{
	NSString* messageString = [NSString stringWithCString:message.SA_terminatedCString encoding:_encoding];
	[_delegate messageSent:messageString byUser:nick];
}

- (void)noticeSent:(NSData *)notice byUser:(NSString *)nick
{
	NSString* noticeString = [NSString stringWithCString:notice.SA_terminatedCString encoding:_encoding];
	[_delegate noticeSent:noticeString byUser:nick];
}

- (void)actionPerformed:(NSData *)action byUser:(NSString *)nick
{
	NSString* actionString = [NSString stringWithCString:action.SA_terminatedCString encoding:_encoding];
	[_delegate actionPerformed:actionString byUser:nick];
}

@end
