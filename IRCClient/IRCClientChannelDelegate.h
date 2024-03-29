//
//	IRCClientChannelDelegate.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import <Foundation/Foundation.h>

/** @brief Receives delegate messages from an IRCClientChannel.
 *
 *	Each IRCClientChannel object needs a delegate. Delegate methods are called
 *  for each event that occurs on an IRC channel that the client is current on.
 *
 *  Note that for any given parameter, it may be optional, in which case a nil
 *  object may be supplied instead of the given parameter.
 */

@class IRCClientChannel;

@protocol IRCClientChannelDelegate <NSObject>

/** When a client joins this channel, the userJoined event is fired. Note that
 *  the nickname is most likely in nick!user\@host format, but may simply be a
 *  nickname, depending on the server implementation.
 *
 *  You should also expect to see this event when the client first joins a channel,
 *	with a parameter of the client’s nickname.
 *
 *  @param nick The nickname of the user that joined the channel.
 */
-(void) userJoined:(NSData *)nick 
		   channel:(IRCClientChannel *)session;

/** When an IRC client parts a channel you are connect to, you will see
 *  an onPart event. You will also see this event when you part a channel.
 *
 *  @param nick (required) The nickname of the user that left the channel.
 *  @param reason (optional) The reason, if any, that the user gave for leaving.
 *	@param wasItUs (required) Was it us who parted, or another user?
 */
-(void) userParted:(NSData *)nick 
		   channel:(IRCClientChannel *)session
		withReason:(NSData *)reason 
				us:(BOOL)wasItUs;

/** Received when an IRC client changes the channel mode. What modes are available
 *  for a given channel is an implementation detail for each server.
 *
 *  @param mode The new channel mode.
 *  @param params Any parameters with the mode (such as channel key).
 *  @param nick The nickname of the IRC client that changed the mode.
 */
-(void) modeSet:(NSData *)mode 
	 forChannel:(IRCClientChannel *)session
	 withParams:(NSData *)params 
			 by:(NSData *)nick;

/** Received when the topic is changed for the channel.
 *	
 *  @param aTopic The new topic of the channel. 
 *  @param nick Nickname of the IRC client that changed the topic.
 */
-(void) topicSet:(NSData *)topic 
	  forChannel:(IRCClientChannel *)session
			  by:(NSData *)nick;

/** Received when an IRC client is kicked from a channel.
 *
 *  @param nick Nickname of the client that was kicked.
 *  @param reason Reason message given for the kick.
 *  @param byNick Nickname of the client that performed the kick command.
 *	@param wasItUs Was it us who got kicked, or another user?
 */
-(void) userKicked:(NSData *)nick 
	   fromChannel:(IRCClientChannel *)session
		withReason:(NSData *)reason 
				by:(NSData *)byNick 
				us:(BOOL)wasItUs;

/** Received when an IRC client sends a public PRIVMSG to the channel. Note that the
 *  user may not necessarily be required to be on the channel to send a message
 *	to it.
 *
 *  @param message The message sent to the channel.
 *  @param nick The nickname of the IRC client that sent the message.
 */
-(void) messageSent:(NSData *)message 
			 byUser:(NSData *)nick 
		  onChannel:(IRCClientChannel *)session;

/** Received when an IRC client sends a public NOTICE to the channel. Note that
 *	the user may not necessarily be required to be on the channel to send a notice to
 *	it. Furthermore, the RFC states that the only difference between PRIVMSG and
 *  NOTICE is that a NOTICE may never be responded to automatically.
 *
 *  @param notice The notice sent to the channel.
 *  @param nick The nickname of the IRC client that sent the notice.
 */
-(void) noticeSent:(NSData *)notice 
			byUser:(NSData *)nick 
		 onChannel:(IRCClientChannel *)session;

/** Received when an IRC client sends a CTCP ACTION message to the channel.
 *
 *  @param action The action message sent to the channel.
 *  @param nick The nickname of the IRC client that sent the message.
 */
-(void) actionPerformed:(NSData *)action 
				 byUser:(NSData *)nick 
			  onChannel:(IRCClientChannel *)session;

@end
