//
//	IRCClientChannel.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import <Foundation/Foundation.h>
#import "IRCClientChannelDelegate.h"

/** \class IRCClientChannel
 *	@brief Represents a connected IRC Channel.
 *
 *	IRCClientChannel objects are created by the IRCClientSession object
 *  for a given session when the client joins an IRC channel.
 */

@class IRCClientSession;

/**********************************************/
#pragma mark IRCClientChannel class declaration
/**********************************************/

@interface IRCClientChannel : NSObject

/************************/
#pragma mark - Properties
/************************/

/** Delegate to send events to. */
@property (assign) id <IRCClientChannelDelegate> delegate;

/** Associated session. */
@property (readonly) IRCClientSession *session;

/** Name of the channel. */
@property (readonly) NSData *name;

/** Encoding used by, and in, this channel. */
@property (assign) NSStringEncoding encoding;

/** Topic of the channel
 *
 *	You can (attempt to) set the topic by using -[setChannelTopic:], not by
 *	changing this property (which is readonly). If the connected user has the
 *	privileges to set the channel topic, the channel’s delegate will receive a
 *	-[topicSet:forChannel:by:] message (and the topic property of the channel 
 *	object will be updated automatically).
 */
@property (readonly) NSData *topic;

/** Modes of the channel. */
@property (readonly) NSData *modes;

/** An array of nicknames stored as NSData objects that list the connected users
    for the channel. */
@property (readonly) NSArray *nicks;

/** Stores arbitrary user info. */
@property (strong) NSDictionary *userInfo;

/********************************************/
#pragma mark - Initializers & factory methods
/********************************************/

+(instancetype) channel;

/**************************/
#pragma mark - IRC commands
/**************************/

/** Parts the channel. */
-(int) part;

/** Invites another IRC client to the channel.
 *
 *  @param nick The nickname of the client to invite.
 */
-(int) invite:(NSData *)nick;

/** Sets the topic of the channel.
 *
 *	Note that not all users on a channel have permission to change the topic; 
 *	if you fail to set the topic, then you will not see 
 *	a -[topicSet:forChannel:by:] event on the IRCClientChannelDelegate.
 *
 *  @param aTopic The topic the client wishes to set for the channel.
 */
-(int) setChannelTopic:(NSData *)newTopic;

/** Sets the mode of the channel.
 *
 *	Note that not all users on a channel have permission to change the mode; 
 *	if you fail to set the mode, then you will not see a 
 *	-[modeSet:forChannel:withParams:by:] event on the IRCClientChannelDelegate.
 *
 *  @param mode The mode to set the channel to.
 */
-(int) setMode:(NSData *)mode 
		params:(NSData *)params;

/** Sends a public PRIVMSG to the channel. If you try to send more than 
	can fit on an IRC buffer, it will be truncated.
 
    @param message The message to send to the channel.
 */
-(int) message:(NSData *)message;

/** Sends a public CTCP ACTION to the channel.
 *
 *  @param action Action to send to the channel.
 */
-(int) action:(NSData *)action;

/** Sends a public NOTICE to the channel.
 *
 *  @param notice Message to send to the channel.
 */
-(int) notice:(NSData *)notice;

/** Kicks someone from a channel.
 *
 *  @param nick The IRC client to kick from the channel.
 *  @param reason The message to give to the channel and the IRC client for the kick.
 */
-(int) kick:(NSData *)nick 
	 reason:(NSData *)reason;

/** Sends a CTCP request to the channel.
 *
 *	It is perfectly legal to send a CTCP request to an IRC channel; 
 *	however, many clients decline to respond to them, and often they are 
 *	percieved as annoying.
 *
 *  @param request The string of the request, in CTCP format.
 */
-(int) ctcpRequest:(NSData *)request;

@end
