//
//  IRCClientChannel_Private.h
//  Meil
//
//  Copyright 2015 Said Achmiz (www.saidachmiz.net)
//

#import "IRCClientChannel.h"

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

- (void)userJoined:(NSString *)nick;

- (void)userParted:(NSString *)nick withReason:(NSData *)reason us:(BOOL)wasItUs;

- (void)modeSet:(NSString *)mode withParams:(NSString *)params by:(NSString *)nick;

- (void)topicSet:(NSData *)newTopic by:(NSString *)nick;

- (void)userKicked:(NSString *)nick withReason:(NSData *)reason by:(NSString *)byNick us:(BOOL)wasItUs;

- (void)messageSent:(NSData *)message byUser:(NSString *)nick;

- (void)noticeSent:(NSData *)notice byUser:(NSString *)nick;

- (void)actionPerformed:(NSData *)action byUser:(NSString *)nick;

@end
