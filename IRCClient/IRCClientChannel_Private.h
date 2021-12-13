//
//  IRCClientChannel_Private.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import "IRCClientChannel.h"
#import "IRCClientSession.h"
#include "libircclient.h"

/********************************************/
#pragma mark IRCClientChannel class extension
/********************************************/

@interface IRCClientChannel ()

/** initWithName:andIRCSession:
 *
 *	Returns an initialised IRCClientChannel with a given channel name, associated
 *  with the given irc_session_t object. You are not expected to initialize your
 *  own IRCClientChannel objects; if you wish to join a channel you should send a
 *  [IRCClientSession join:key:] message to your IRCClientSession object.
 *
 *  @param aName Name of the channel.
 */
-(instancetype) initWithName:(NSData *)aName
			   andIRCSession:(irc_session_t *)session;

/****************************/
#pragma mark - Event handlers
/****************************/

/*	NOTE: These methods are not to be called by classes that use IRCClient;
 *	they are for the framework’s internal use only. Do not import this header
 *	in files that make use of the IRCClientChannel class.
 */

-(void) userJoined:(NSData *)nick;

-(void) userParted:(NSData *)nick 
		withReason:(NSData *)reason 
				us:(BOOL)wasItUs;

-(void) modeSet:(NSData *)mode 
	 withParams:(NSData *)params 
			 by:(NSData *)nick;

-(void) topicSet:(NSData *)newTopic 
			  by:(NSData *)nick;

-(void) userKicked:(NSData *)nick 
		withReason:(NSData *)reason 
				by:(NSData *)byNick 
				us:(BOOL)wasItUs;

-(void) messageSent:(NSData *)message 
			 byUser:(NSData *)nick;

-(void) noticeSent:(NSData *)notice 
			byUser:(NSData *)nick;

-(void) actionPerformed:(NSData *)action 
				 byUser:(NSData *)nick;

@end
