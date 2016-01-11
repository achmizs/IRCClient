//
//	IRCClientChannel.h
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

#import <Cocoa/Cocoa.h>
#import "IRCClientChannelDelegate.h"

/** \class IRCClientChannel
 *	@brief Represents a connected IRC Channel.
 *
 *	IRCClientChannel objects are created by the IRCClientSession object
 *  for a given session when the client joins an IRC channel.
 */

/**********************************************/
#pragma mark IRCClientChannel class declaration
/**********************************************/

@interface IRCClientChannel : NSObject

/************************/
#pragma mark - Properties
/************************/

/** Delegate to send events to */
@property (assign) id <IRCClientChannelDelegate> delegate;

/** Name of the channel */
@property (readonly) NSData *name;

/** Encoding used by, and in, this channel */
@property (assign) NSStringEncoding encoding;

/** Topic of the channel
 *
 *	You can (attempt to) set the topic by using setChannelTopic:, not by 
 *	changing this property (which is readonly). If the connected user has the
 *	privileges to set the channel topic, the channel's delegate will receive a
 *	topicSet:by: message (and the topic property of the channel object will be
 *	updated automatically).
 */
@property (readonly) NSData *topic;

/** Modes of the channel */
@property (readonly) NSData *modes;

/** An array of nicknames stored as NSData objects that list the connected users
    for the channel */
@property (readonly) NSArray *nicks;

/**************************/
#pragma mark - IRC commands
/**************************/

/** Parts the channel. */
- (int)part;

/** Invites another IRC client to the channel.
 *
 *  @param nick the nickname of the client to invite.
 */
- (int)invite:(NSData *)nick;

/** Sets the topic of the channel.
 *
 *	Note that not all users on a channel have permission to change the topic; if you fail
 *	to set the topic, then you will not see a topicSet:by: event on the IRCClientChannelDelegate.
 *
 *  @param aTopic the topic the client wishes to set for the channel.
 */
- (void)setChannelTopic:(NSData *)newTopic;

/** Sets the mode of the channel.
 *
 *	Note that not all users on a channel have permission to change the mode; if you fail
 *	to set the mode, then you will not see a modeSet:withParams:by: event on the IRCClientChannelDelegate.
 *
 *  @param mode the mode to set the channel to
 */
- (int)setMode:(NSData *)mode params:(NSData *)params;

/** Sends a public PRIVMSG to the channel. If you try to send more than can fit on an IRC
  	buffer, it will be truncated.
 
    @param message the message to send to the channel.
 */
- (int)message:(NSData *)message;

/** Sends a public CTCP ACTION to the channel.
 *
 *  @param action action to send to the channel.
 */
- (int)action:(NSData *)action;

/** Sends a public NOTICE to the channel.
 *
 *  @param notice message to send to the channel.
 */
- (int)notice:(NSData *)notice;

/** Kicks someone from a channel.
 *
 *  @param nick the IRC client to kick from the channel.
 *  @param reason the message to give to the channel and the IRC client for the kick.
 */
- (int)kick:(NSData *)nick reason:(NSData *)reason;

/** Sends a CTCP request to the channel.
 *
 *	It is perfectly legal to send a CTCP request to an IRC channel, however many clients
 *	decline to respond to them, and often they are percieved as annoying.
 *
 *  @param request the string of the request, in CTCP format.
 */
- (int)ctcpRequest:(NSData *)request;

@end
