//
//	IRCClientSession.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

#import <Foundation/Foundation.h>
#import "IRCClientSessionDelegate.h"

/** @class IRCClientSession
 *	@brief Represents a connected IRC Session.
 *
 *	IRCClientSession represents a single connection to an IRC server. After initialising
 *  the object, setting the delegate, server, port, and password (if required)
 *	properties, and setting the nickname, username and realname using the
 *	setNickname:username:realname: method, you call the connect: and run: methods 
 *	to connect to the IRC server and place the connection on a new event queue.
 *
 *	This thread then sends messages to the IRC server delegate,
 *	or to the IRCClientChannel delegate, as required.
 */

/**********************************************/
#pragma mark IRCClientSession class declaration
/**********************************************/

@interface IRCClientSession : NSObject <NSStreamDelegate>

/******************************/
#pragma mark - Class properties
/******************************/

/**	Returns a dictionary of IRC numeric codes.

	The dictionary contains entries for all known IRC numeric codes (as keys).
	(The list is taken from https://www.alien.net.au/irc/irc2numerics.html .)

	The value for each key is an NSArray with the known numeric reply names for
	which the numeric code is used.

	Note that there is no guarantee whatsoever that any given numeric reply
	name will, in fact, describe the contents of the message; most IRC numeric
	messages have implementation-specific uses. See the various RFCs, and other
	info sources, for details.
 */
@property (class, nonatomic, readonly) NSDictionary <NSString *, NSDictionary *> *ircNumericCodes;

/************************/
#pragma mark - Properties
/************************/

/** Delegate to send events to. */
@property (assign) id <IRCClientSessionDelegate> delegate;

/** The version string for the client to send back on CTCP VERSION requests.
	There is usually no reason to set this, as IRCClient correctly sets its
	own version string automatically, but this can be any string you like.
 */
@property (copy, nonatomic) NSData *version;

/** IRC server to connect to. */
@property (copy, nonatomic) NSData *server;

/** IRC port to connect to. */
@property (assign) NSUInteger port;

/** Server password to provide on connect (may be left empty or nil). */
@property (copy, nonatomic) NSData *password;

/** Nickname of the connected client.
 */
@property (nonatomic, readonly) NSData *nickname;

/** Username of the connected client. Also known as the ident.
 */
@property (nonatomic, readonly) NSData *username;

/** Realname of the connected client.
 */
@property (nonatomic, readonly) NSData *realname;

/** The suggested text encoding for messages on this server.
 
	This is almost entirely irrelevant (except for CTCP TIME replies), as 
	all messages and other strings are taken and returned as  NSData objects. 
	This property is for your convenience.
 
	You may change this at any time.
 */
@property (assign) NSStringEncoding encoding;

/** An NSDictionary of channels that the client is currently connected to.
	Keys are channel names (NSData), values are IRCClientChannel objects.
 */
@property (nonatomic, readonly) NSDictionary <NSData *, IRCClientChannel *> *channels;

/** Returns YES if the server is currently connected successfully, and NO if
	it is not. */
@property (readonly, getter=isConnected) BOOL connected;

/** Stores arbitrary user info. */
@property (nonatomic, readonly) NSMutableDictionary *userInfo;

/********************************************/
#pragma mark - Initializers & factory methods
/********************************************/

+(instancetype) session;

/***************************/
#pragma mark - Class methods
/***************************/

/**	Returns the nick part of a nick!user@host string.
 */
+(NSData *) nickFromNickUserHost:(NSData *)nickUserHost;

/**	Returns the user part of a nick!user@host string.
	May be blank if the user component can’t be found
	(i.e. if the passed string is not, in fact, in nick!user@host format).
 */
+(NSData *) userFromNickUserHost:(NSData *)nickUserHost;

/**	Returns the host part of a nick!user@host string.
	May be blank if the host component can’t be found
	(i.e. if the passed string is not, in fact, in nick!user@host format).
 */
+(NSData *) hostFromNickUserHost:(NSData *)nickUserHost;

/******************************/
#pragma mark - Instance methods
/******************************/

/** Set the nickname, username, and realname for the session.
 
	Returns YES if successfully set, NO otherwise.
	(NO is returned if you try to call this method after the session has
	already connected; use the nick: method to attempt a nick change while
	connected.)
 */
-(BOOL) setNickname:(NSData *)nickname
		   username:(NSData *)username
		   realname:(NSData *)realname;

/** Connect to the IRC server.
 
	Note that this performs the initial DNS lookup and the TCP connection, so if
	there are any problems you will be notified via the return code of the message.

	Look at the libircclient documentation for the different return codes.
 */
-(int) connect;

/** Disconnect from the IRC server.
 
	This always works, as it simply shuts down the socket. If you want to disconnect
	in a friendly way, you should use the quit: message.
 */
-(void) disconnect;

/** Convert libircclient markup in a message to mIRC format codes.
 */
-(NSData *) colorConvertToMIRC:(NSData *)message;

/** Convert mIRC format codes in a message to libircclient markup.
 */
-(NSData *) colorConvertFromMIRC:(NSData *)message;

/** Remove mIRC format codes from a message.
 */
-(NSData *) colorStripFromMIRC:(NSData *)message;

/**************************/
#pragma mark - IRC commands
/**************************/

/** Sends a raw message to the IRC server. Please consult RFC 1459 for the 
	format of IRC commands. 
 */
-(int) sendRaw:(NSData *)message;

/** Quits the IRC server with the given reason.
 
	On success, a -[userQuit:withReason:session:] event will be sent to the 
	IRCClientSessionDelegate with the nickname of the IRC client and the reason 
	provided by the user (or nil if no reason was provided).
 
	@param reason The quit reason.
 */
-(int) quit:(NSData *)reason;

/** Joins a channel with a given name and key.
 
	On success, a -[joinedNewChannel:session:] event will be sent to the
	IRCClientSessionDelegate with the IRCClientChannel object representing the
	newly-joined channel.
 
	@param channel The name of the channel to join.
	@param key The key for the channel (may be nil).
 */
-(int) join:(NSData *)channel 
		key:(NSData *)key;

/**	Lists users in an IRC channel (or channels).

	@param channel A channel name or string to pass to the NAMES command.
	Implementation specific.
 */
-(int) names:(NSData *)channel;

/**	Lists channels on the IRC server.
 
	@param channel A channel name or string to pass to the LIST command.
	Implementation specific.
 */
-(int) list:(NSData *)channel;

/** Sets the user mode for the IRC client.
 
	@param mode The mode string to set.
 */
-(int) userMode:(NSData *)mode;

/**	Sets the IRC client nickname.
 
	On success, a nickChangedFrom:to: event will be sent to the 
	IRCClientSessionDelegate with our old nick and the new nick that we now 
	have.
 
	@param newnick The new nickname to set.
 */
-(int) nick:(NSData *)newnick;

/**	Sends a WHO query to the IRC server.

	@param nickmask Nickname mask of the IRC client to WHO.
 */
-(int) who:(NSData *)nickmask;

/**	Sends a WHOIS query to the IRC server.
 
	@param nick Nickname of the IRC client to WHOIS.
*/
-(int) whois:(NSData *)nick;

/**	Send a PRIVMSG to another IRC client.
 
	@param message Message to send.
	@param target The other IRC client to send the message to.
 */
-(int) message:(NSData *)message 
			to:(NSData *)target;

/**	Sends a CTCP ACTION to another IRC client.
 
	@param action The action message to send.
	@param target The nickname of the irc client to send the message to.
 */
-(int) action:(NSData *)action 
		   to:(NSData *)target;

/**	Send a NOTICE to another IRC client.
 
	@param notice The message text to send.
	@param target The nickname of the irc client to send the notice to.
 */
-(int) notice:(NSData *)notice 
		   to:(NSData *)target;

/** Send a CTCP request to another IRC client.
 
	@param request The CTCP request string to send.
	@param target The nickname of the IRC client to send the request to.
 */
-(int) ctcpRequest:(NSData *)request 
			target:(NSData *)target;

/** Send a CTCP reply to another IRC client.
 
	@param reply The CTCP reply string to send.
	@param target The nickname of the IRC client to send the reply to.
 */
-(int) ctcpReply:(NSData *)reply 
		  target:(NSData *)target;

@end
