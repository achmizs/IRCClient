//
//	IRCClientSessionDelegate.h
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

@class IRCClientChannel;

/** @brief Receives delegate messages from an IRCClientSession.
 *
 *	Each IRCClientSession object needs a single delegate. Methods are called
 *  for each event that occurs on an IRC server that the client is connected to.
 *
 *  Note that for any given parameter, it may be optional, in which case a nil
 *  object may be supplied instead of the given parameter.
 */

@protocol IRCClientSessionDelegate <NSObject>

/** The client has successfully connected to the IRC server. */
- (void)connectionSucceeded;

/** An IRC client on a channel that this client is connected to has changed nickname,
 *	or this IRC client has changed nicknames.
 *
 *  @param nick the new nickname
 *	@param oldNick the old nickname
 *  @param wasItUs did our nick change, or someone else's?
 */
- (void)nickChangedFrom:(NSString *)oldNick to:(NSString *)newNick own:(BOOL)wasItUs;

/** An IRC client on a channel that this client is connected to has quit IRC.
 *
 *  @param nick the nickname of the client that quit.
 *  @param reason (optional) the quit message, if any.
 */
- (void)userQuit:(NSString *)nick withReason:(NSString *)reason;

/** The IRC client has joined (connected) successfully to a new channel. This
 *  event creates an IRCClientChannel object, which you are expected to assign a
 *  delegate to, to handle events from the channel.
 *
 *	For example, on receipt of this message, a graphical IRC client would most
 *  likely open a new window, create an IRCClientChannelDelegate for the window,
 *  set the new IRCClientChannel's delegate to the new delegate, and then hook
 *  it up so that new events sent to the IRCClientChannelDelegate are sent to 
 *  the window.
 *
 *  @param channel the IRCClientChannel object for the newly joined channel.
 */
- (void)joinedNewChannel:(IRCClientChannel *)channel;

/** The client has changed it's user mode.
 *
 *  @param mode the new mode.
 */
- (void)modeSet:(NSString *)mode by:(NSString *)nick;

/** The client has received a private PRIVMSG from another IRC client.
 *
 *  @param message the text of the message
 *  @param nick the other IRC Client that sent the message.
 */
- (void)privateMessageReceived:(NSString *)message fromUser:(NSString *)nick;

/** The client has received a private NOTICE from another client.
 *
 *  @param notice the text of the message
 *  @param nick the nickname of the other IRC client that sent the message.
 */
- (void)privateNoticeReceived:(NSString *)notice fromUser:(NSString *)nick;

/** The client has received a private PRIVMSG from the server.
 *
 *  @param origin the sender of the message
 *  @param params the parameters of the message
 */
- (void)serverMessageReceivedFrom:(NSString *)origin params:(NSArray *)params;

/** The client has received a private NOTICE from the server.
 *
 *  @param origin the sender of the notice
 *  @param params the parameters of the notice
 */
- (void)serverNoticeReceivedFrom:(NSString *)origin params:(NSArray *)params;

/** The IRC client has been invited to a channel.
 *	
 *	Note that the name is provided as an NSData object, because we have no idea
 *	what encoding the channel name is in (it needn't be the same as used by e.g.
 *	server messages, etc.), and it's important to attempt to join *exactly* the
 *	channel you're being invited to, byte for byte, otherwise you might end up
 *	joining the wrong channel. You should convert the name to an NSString for 
 *	display (using the encoding set for the server is probably a sane default)
 *	but be aware that you might be displaying entirely wrong characters and are 
 *	not gauranteed that the channel name will look right - only that it will be 
 *	actually be the right name, internally.
 *
 *  @param channel the channel for the invitation.
 *  @param nick the nickname of the user that sent the invitation.
 */	
- (void)invitedToChannel:(NSData *)channelName by:(NSString *)nick;

/** A private CTCP request was sent to the IRC client.
 *
 *  @param request the CTCP request string (after the type)
 *  @param type the CTCP request type
 *  @param nick the nickname of the user that sent the request.
 */
- (void)CTCPRequestReceived:(NSData *)request ofType:(NSData *)type fromUser:(NSString *)nick;

/** A private CTCP reply was sent to the IRC client.
 *
 *  @param reply an NSData containing the raw C string of the reply.
 *  @param nick the nickname of the user that sent the reply.
 */
- (void)CTCPReplyReceived:(NSData *)reply fromUser:(NSString *)nick;

/** A private CTCP ACTION was sent to the IRC client.
 *
 *  CTCP ACTION is not limited to channels; it may also be sent directly to other users.
 *
 *  @param action the action message text.
 *  @param nick the nickname of the client that sent the action.
 */
- (void)privateCTCPActionReceived:(NSString *)action fromUser:(NSString *)nick;

/** An unhandled event was received from the IRC server.
 *
 *  @param event the unknown event name
 *  @param origin the sender of the event
 *  @param params an NSArray of NSData objects that are the raw C strings of the event.
 */
- (void)unknownEventReceived:(NSData *)event from:(NSString *)origin params:(NSArray *)params;

/** An unhandled numeric was received from the IRC server
 *
 *  @param event the unknown event number
 *  @param origin the sender of the event
 *  @param params an NSArray of NSData objects that are the raw C strings of the event.
 */
- (void)numericEventReceived:(NSUInteger)event from:(NSString *)origin params:(NSArray *)params;

@end
