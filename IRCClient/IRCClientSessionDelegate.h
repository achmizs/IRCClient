//
//	IRCClientSessionDelegate.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import <Foundation/Foundation.h>

@class IRCClientSession;
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
@required
-(void) connectionSucceeded:(IRCClientSession *)session;

/** The client has disconnected from the IRC server. */
@required
-(void) disconnected:(IRCClientSession *)session;

/** The client has received a PING message.
 *
 *	(The contents of a PING could be anything. Sometimes it’s the server’s
 *	 hostname, sometimes other things...)
 *	
 *	@param pingData The contents of the PING message.
 *	@param origin (optional) Where (who) the PING came from.
 */
@optional
-(void) ping:(NSData *)pingData
		from:(NSData *)origin
	 session:(IRCClientSession *)session;

/** An IRC client on a channel that this client is connected to has changed nickname,
 *	or this IRC client has changed nicknames.
 *
 *  @param nick The new nickname.
 *	@param oldNick The old nickname.
 *  @param wasItUs Did our nick change, or someone else’s?
 */
@required
-(void) nickChangedFrom:(NSData *)oldNick 
					 to:(NSData *)newNick 
					own:(BOOL)wasItUs 
				session:(IRCClientSession *)session;

/** An IRC client on a channel that this client is connected to has quit IRC.
 *
 *  @param nick The nickname of the client that quit.
 *  @param reason (optional) The quit message, if any.
 */
@required
-(void) userQuit:(NSData *)nick 
	  withReason:(NSData *)reason 
		 session:(IRCClientSession *)session;

/** The IRC client has joined (connected) successfully to a new channel. This
 *  event creates an IRCClientChannel object, which you are expected to assign a
 *  delegate to, to handle events from the channel.
 *
 *	For example, on receipt of this message, a graphical IRC client would most
 *  likely open a new window, create an IRCClientChannelDelegate for the window,
 *  set the new IRCClientChannel’s delegate to the new delegate, and then hook
 *  it up so that new events sent to the IRCClientChannelDelegate are sent to 
 *  the window.
 *
 *  @param channel The IRCClientChannel object for the newly joined channel.
 */
@required
-(void) joinedNewChannel:(IRCClientChannel *)channel 
				 session:(IRCClientSession *)session;

/** The client’s user mode has been changed.
 *
 *  @param mode The new mode.
 *	@param nick The person who changed the user mode (client itself, or it could
 *		have been a channel operator, etc.).
 */
@required
-(void) modeSet:(NSData *)mode 
			 by:(NSData *)nick 
		session:(IRCClientSession *)session;

/** The client has received an ERROR message from the server.
 */
@required
-(void) errorReceived:(NSData *)error
			  session:(IRCClientSession *)session;

/** The client has received a private PRIVMSG from another IRC client.
 *
 *  @param message The text of the message.
 *  @param nick The other IRC Client that sent the message.
 */
@required
-(void) privateMessageReceived:(NSData *)message 
					  fromUser:(NSData *)nick 
					   session:(IRCClientSession *)session;

/** The client has received a private NOTICE from another client.
 *
 *  @param notice The text of the message.
 *  @param nick The nickname of the other IRC client that sent the message.
 */
@required
-(void) privateNoticeReceived:(NSData *)notice 
					 fromUser:(NSData *)nick 
					  session:(IRCClientSession *)session;

/** The client has received a private PRIVMSG from the server.
 *
 *  @param origin The sender of the message.
 *  @param params The parameters of the message.
 */
@required
-(void) serverMessageReceivedFrom:(NSData *)origin
						   params:(NSArray *)params
						  session:(IRCClientSession *)session;

/** The client has received a private NOTICE from the server.
 *
 *  @param origin The sender of the notice.
 *  @param params The parameters of the notice.
 */
@required
-(void) serverNoticeReceivedFrom:(NSData *)origin 
						  params:(NSArray *)params 
						 session:(IRCClientSession *)session;

/** The IRC client has been invited to a channel.
 *
 *  @param channelName The name of the channel for the invitation.
 *  @param nick The nickname of the user that sent the invitation.
 */	
@required
-(void) invitedToChannel:(NSData *)channelName 
					  by:(NSData *)nick 
				 session:(IRCClientSession *)session;

/** A private CTCP request was sent to the IRC client.
 *
 *  @param request The CTCP request string (after the type).
 *  @param type The CTCP request type.
 *  @param nick The nickname of the user that sent the request.
 */
@optional
-(void) CTCPRequestReceived:(NSData *)request 
					 ofType:(NSData *)type 
				   fromUser:(NSData *)nick 
					session:(IRCClientSession *)session;

/** A private CTCP reply was sent to the IRC client.
 *
 *  @param reply An NSData containing the raw C string of the reply.
 *  @param nick The nickname of the user that sent the reply.
 */
@optional
-(void) CTCPReplyReceived:(NSData *)reply 
				 fromUser:(NSData *)nick 
				  session:(IRCClientSession *)session;

/** A private CTCP ACTION was sent to the IRC client.
 *
 *  CTCP ACTION is not limited to channels; it may also be sent directly to other users.
 *
 *  @param action The action message text.
 *  @param nick The nickname of the client that sent the action.
 */
@required
-(void) privateCTCPActionReceived:(NSData *)action 
						 fromUser:(NSData *)nick 
						  session:(IRCClientSession *)session;

/** An unhandled numeric was received from the IRC server
 *
 *  @param event The unknown event number.
 *  @param origin The sender of the event.
 *  @param params An NSArray of NSData objects that are the raw C strings of the event.
 */
@optional
-(void) numericEventReceived:(NSUInteger)event 
						from:(NSData *)origin 
					  params:(NSArray *)params 
					 session:(IRCClientSession *)session;

/** An unhandled event was received from the IRC server.
 *
 *  @param event The unknown event name.
 *  @param origin The sender of the event.
 *  @param params An NSArray of NSData objects that are the raw C strings of the event.
 */
@optional
-(void) unknownEventReceived:(NSData *)event 
						from:(NSData *)origin 
					  params:(NSArray *)params 
					 session:(IRCClientSession *)session;

@end
