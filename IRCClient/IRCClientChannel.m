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

#import "IRCClientChannel.h"
#import "IRCClientSession.h"
#import "IRCClientChannel_Private.h"

#pragma mark IRCClientChannel private category

@interface IRCClientChannel()
{
	NSData				*name;
	irc_session_t		*irc_session;
	NSStringEncoding	encoding;
	NSData				*topic;
	NSString			*modes;
	NSMutableArray		*nicks;
}

@property (nonatomic, retain) NSMutableArray *nicks;

@end

#pragma mark - IRCClientChannel class implementation

@implementation IRCClientChannel

#pragma mark - Property synthesis

@synthesize delegate;
@synthesize name;
@synthesize encoding;
@synthesize topic;
@synthesize modes;

#pragma mark - Custom accessors

-(NSArray *)nicks
{
	NSArray* nicksCopy = [nicks copy];
	return nicksCopy;
}

-(void)setNicks:(NSArray *)newNicks
{
	nicks = [newNicks mutableCopy];
}

/**************************/
#pragma mark - Initializers
/**************************/

-(instancetype)initWithName:(NSData *)aName andIRCSession:(irc_session_t *)session
{
    if ((self = [super init])) {
		name = aName;
		irc_session = session;
		topic = [NSData dataWithBytes:@"".UTF8String length:1];
		encoding = NSUTF8StringEncoding;
	}
	
	return self;
}

/**************************/
#pragma mark - IRC commands
/**************************/

- (int)part
{
	return irc_cmd_part(irc_session, name.bytes);
}

- (int)invite:(NSString *)nick
{
	return irc_cmd_invite(irc_session, nick.UTF8String, name.bytes);
}

- (int)refreshNames
{
	return irc_cmd_names(irc_session, name.bytes);
}

- (void)setChannelTopic:(NSString *)newTopic
{	
	irc_cmd_topic(irc_session, name.bytes, [newTopic cStringUsingEncoding:encoding]);
}

- (int)setMode:(NSString *)mode params:(NSString *)params
{
	NSMutableString* modeString = [mode mutableCopy];
	
	if(params != nil && params.length > 0)
		[modeString appendFormat:@" %@", params];
	
	return irc_cmd_channel_mode(irc_session, name.bytes, modeString.UTF8String);
}

- (int)message:(NSString *)message
{
	return irc_cmd_msg(irc_session, name.bytes, [message cStringUsingEncoding:encoding]);
}

- (int)action:(NSString *)action
{
	return irc_cmd_me(irc_session, name.bytes, [action cStringUsingEncoding:encoding]);
}

- (int)notice:(NSString *)notice
{
	return irc_cmd_notice(irc_session, name.bytes, [notice cStringUsingEncoding:encoding]);
}

- (int)kick:(NSString *)nick reason:(NSString *)reason
{
	return irc_cmd_kick(irc_session, nick.UTF8String, name.bytes, [reason cStringUsingEncoding:encoding]);
}

- (int)ctcpRequest:(NSData *)request
{
	return irc_cmd_ctcp_request(irc_session, name.bytes, request.bytes);
}

/****************************/
#pragma mark - Event handlers
/****************************/

- (void)userJoined:(NSString *)nick
{
	[delegate userJoined:nick];
}

- (void)userParted:(NSString *)nick withReason:(NSData *)reason us:(BOOL)wasItUs
{
	NSString* reasonString = [[NSString alloc] initWithData:reason encoding:encoding];
	[delegate userParted:nick withReason:reasonString us:wasItUs];
}

- (void)modeSet:(NSString *)mode withParams:(NSString *)params by:(NSString *)nick
{
	[delegate modeSet:mode withParams:params by:nick];
}

- (void)topicSet:(NSData *)newTopic by:(NSString *)nick
{
	topic = newTopic;
	
	NSString* topicString = [[NSString alloc] initWithData:topic encoding:encoding];
	[delegate topicSet:topicString by:nick];
}

- (void)userKicked:(NSString *)nick withReason:(NSData *)reason by:(NSString *)byNick us:(BOOL)wasItUs
{
	NSString* reasonString = [[NSString alloc] initWithData:reason encoding:encoding];
	[delegate userKicked:nick withReason:reasonString by:byNick us:wasItUs];
}

- (void)messageSent:(NSData *)message byUser:(NSString *)nick
{
	NSString* messageString = [[NSString alloc] initWithData:message encoding:encoding];
	[delegate messageSent:messageString byUser:nick];
}

- (void)noticeSent:(NSData *)notice byUser:(NSString *)nick
{
	NSString* noticeString = [[NSString alloc] initWithData:notice encoding:encoding];
	[delegate noticeSent:noticeString byUser:nick];
}

- (void)actionPerformed:(NSData *)action byUser:(NSString *)nick
{
	NSString* actionString = [[NSString alloc] initWithData:action encoding:encoding];
	[delegate actionPerformed:actionString byUser:nick];
}

@end
