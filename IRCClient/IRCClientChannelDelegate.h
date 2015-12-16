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

/** 
 * @file IRCClientChannelDelegate.h
 * @author Nathan Ollerenshaw
 * @version 1.0
 * @date 01.2009
 * @brief Receives delegate messages from an IRCClientChannel.
 * @protocol IRCClientChannelDelegate
 */

#import <Cocoa/Cocoa.h>

/** @brief Receives delegate messages from an IRCClientChannel.
 *
 *	Each IRCClientChannel object needs a delegate. Delegate methods are called
 *  for each event that occurs on an IRC channel that the client is current on.
 *
 *  Note that for any given parameter, it may be optional, in which case a nil
 *  object may be supplied instead of the given parameter.
 */

@protocol IRCClientChannelDelegate <NSObject>

/** When a client joins this channel, the userJoined event is fired. Note that
 *  the nickname is most likely in nick!user\@host format, but may simply be a
 *  nickname, depending on the server implementation.
 *
 *  You should also expect to see this event when the client first joins a channel,
 *	with a parameter of the client's nickname.
 *
 *  @param nick The nickname of the user that joined the channel.
 */
- (void)userJoined:(NSString *)nick;

/** When an IRC client parts a channel you are connect to, you will see
 *  an onPart event. You will also see this event when you part a channel.
 *
 *  @param nick (required) The nickname of the user that left the channel.
 *  @param reason (optional) The reason, if any, that the user gave for leaving.
 *	@param wasItUs (required) Was it us who parted, or another user?
 */
- (void)userParted:(NSString *)nick withReason:(NSString *)reason us:(BOOL)wasItUs;

/** Received when an IRC client changes the channel mode. What modes are available
 *  for a given channel is an implementation detail for each server.
 *
 *  @param mode the new channel mode.
 *  @param params any parameters with the mode (such as channel key).
 *  @param nick the nickname of the IRC client that changed the mode.
 */
- (void)modeSet:(NSString *)mode withParams:(NSString *)params by:(NSString *)nick;

/** Received when the topic is changed for the channel.
 *	
 *  @param aTopic The new topic of the channel. 
 *  @param nick Nickname of the IRC client that changed the topic.
 */
- (void)topicSet:(NSString *)newTopic by:(NSString *)nick;

/** Received when an IRC client is kicked from a channel.
 *
 *  @param nick nickname of the client that was kicked
 *  @param reason reason message given for the kick
 *  @param byNick nickname of the client that performed the kick command
 *	@param wasItUs Was it us who got kicked, or another user?
 */
- (void)userKicked:(NSString *)nick withReason:(NSString *)reason by:(NSString *)byNick us:(BOOL)wasItUs;

/** Received when an IRC client sends a public PRIVMSG to the channel. Note that the
 *  user may not necessarily be required to be on the channel to send a message
 *	to it.
 *
 *  @param message the message sent to the channel.
 *  @param nick the nickname of the IRC client that sent the message.
 */
- (void)messageSent:(NSString *)message byUser:(NSString *)nick;

/** Received when an IRC client sends a public NOTICE to the channel. Note that
 *	the user may not necessarily be required to be on the channel to send a notice to
 *	it. Furthermore, the RFC states that the only difference between PRIVMSG and
 *  NOTICE is that a NOTICE may never be responded to automatically.
 *
 *  @param notice the notice sent to the channel.
 *  @param nick the nickname of the IRC client that sent the notice.
 */
- (void)noticeSent:(NSString *)notice byUser:(NSString *)nick;

/** Received when an IRC client sends a CTCP ACTION message to the channel.
 *
 *  @param action the action message sent to the channel.
 *  @param nick the nickname of the IRC client that sent the message.
 */
- (void)actionPerformed:(NSString *)action byUser:(NSString *)nick;

@end
