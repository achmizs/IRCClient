//
//  IRCClientChannel_Private.h
//	IRCClient
/*
 * Copyright 2015 Said Achmiz (www.saidachmiz.net)
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
#include "libircclient.h"

@interface IRCClientChannel ()

/** initWithName:andIRCSession:
 *
 *	Returns an initialised IRCClientChannel with a given channel name, associated
 *  with the given irc_session_t object. You are not expected to initialise your
 *  own IRCClientChannel objects; if you wish to join a channel you should send a
 *  [IRCClientSession join:key:] message to your IRCClientSession object.
 *
 *  @param aName Name of the channel.
 */
-(instancetype)initWithName:(NSData *)aName andIRCSession:(irc_session_t *)session;

/****************************/
#pragma mark - Event handlers
/****************************/

/*	NOTE: These methods are not to be called by classes that use IRCClient;
 *	they are for the framework's internal use only. Do not import this header
 *	in files that make use of the IRCClientChannel class.
 */

- (void)userJoined:(NSData *)nick;

- (void)userParted:(NSData *)nick withReason:(NSData *)reason us:(BOOL)wasItUs;

- (void)modeSet:(NSData *)mode withParams:(NSData *)params by:(NSData *)nick;

- (void)topicSet:(NSData *)newTopic by:(NSData *)nick;

- (void)userKicked:(NSData *)nick withReason:(NSData *)reason by:(NSData *)byNick us:(BOOL)wasItUs;

- (void)messageSent:(NSData *)message byUser:(NSData *)nick;

- (void)noticeSent:(NSData *)notice byUser:(NSData *)nick;

- (void)actionPerformed:(NSData *)action byUser:(NSData *)nick;

@end
