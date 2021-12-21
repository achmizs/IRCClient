//
//	IRCClientSession.m
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

/********************************/
#pragma mark Defines and includes
/********************************/

#define IRCCLIENTVERSION "2.1a1"

#import "IRCClientSession.h"
#import "IRCClientChannel.h"
#import "IRCClientChannel_Private.h"

#import "NSArray+SA_NSArrayExtensions.h"
#import "NSData+SA_NSDataExtensions.h"
#import "NSString+SA_NSStringExtensions.h"
#import "NSRange-Conventional.h"
#import "NSIndexSet+SA_NSIndexSetExtensions.h"
#import "NSStream+QNetworkAdditions.h"

/******************************/
#pragma mark - Static variables
/******************************/

static const char *C_string_crlf = "\r\n";

static NSDictionary* ircNumericCodeList;

/******************************/
#pragma mark - Type definitions
/******************************/

// TODO: more states? maybe to do with the NSStreamDelegate options?
typedef NS_OPTIONS(NSUInteger, IRCClientSessionStateFlags) {
	IRCClientSessionConnected		= 1 << 0,
	IRCClientSessionMOTDReceived	= 1 << 1
};

/***************************************************/
#pragma mark - IRCClientSession class implementation
/***************************************************/

@implementation IRCClientSession {
	NSInputStream *_iStream;
	NSOutputStream *_oStream;

	NSMutableData *_receivedData;
	NSMutableData *_dataToSend;

	dispatch_queue_t _q;

	void (^_cleanupHandler)();

	NSMutableDictionary <NSData *, IRCClientChannel *> *_channels;

	IRCClientSessionStateFlags _stateFlags;
}

/******************************/
#pragma mark - Custom accessors
/******************************/

-(NSDictionary <NSData *, IRCClientChannel *> *) channels {
	return [_channels copy];
}

-(BOOL) isConnected {
	return (_stateFlags & IRCClientSessionConnected);
}

+(NSDictionary *) ircNumericCodes {
	if (ircNumericCodeList == nil)
		[IRCClientSession loadNumericCodes];

	return ircNumericCodeList;
}

/********************************************/
#pragma mark - Initializers & factory methods
/********************************************/

+(instancetype) session {
	return [self new];
}

-(instancetype) init {
	if (!(self = [super init]))
		return nil;

	_version = [[NSString stringWithFormat:@"IRCClient Framework v%s (Said Achmiz)", IRCCLIENTVERSION] dataAsUTF8];

	_channels = [NSMutableDictionary dictionary];
	_encoding = NSUTF8StringEncoding;

	_userInfo = [NSMutableDictionary dictionary];

	_q = dispatch_queue_create("Q", DISPATCH_QUEUE_SERIAL);

	return self;
}

-(void) dealloc {
	if (self.isConnected) {
		NSLog(@"WARNING: IRC Session is not disconnected on dealloc");
	}
}

/***************************/
#pragma mark - Class methods
/***************************/

+(NSData *) nickFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfNickUserSeparator = [nickUserHost rangeOfBytes:"!"
														  options:(NSDataSearchOptions) 0
															range:nickUserHost.fullRange];

	if (rangeOfNickUserSeparator.location == NSNotFound) {
		return nil;
	} else {
		NSRange rangeOfNick = NSRangeMake(0, rangeOfNickUserSeparator.location);
		return [nickUserHost subdataWithRange:rangeOfNick];
	}
}

+(NSData *) userFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfNickUserSeparator = [nickUserHost rangeOfBytes:"!"
														  options:(NSDataSearchOptions) 0
															range:nickUserHost.fullRange];
	NSRange rangeOfUserHostSeparator = [nickUserHost rangeOfBytes:"@"
														  options:(NSDataSearchOptions) 0
															range:nickUserHost.fullRange];

	if (   rangeOfNickUserSeparator.location == NSNotFound
		|| rangeOfUserHostSeparator.location == NSNotFound) {
		return nil;
	} else {
		return [nickUserHost subdataWithRange:NSRangeMake(NSRangeMax(rangeOfNickUserSeparator),
														  rangeOfUserHostSeparator.location - NSRangeMax(rangeOfNickUserSeparator))];
	}
}

+(NSData *) hostFromNickUserHost:(NSData *)nickUserHost {
	if (nickUserHost == nil)
		return nil;

	NSRange rangeOfUserHostSeparator = [nickUserHost rangeOfBytes:"@"
														  options:(NSDataSearchOptions) 0
															range:nickUserHost.fullRange];

	if (rangeOfUserHostSeparator.location == NSNotFound) {
		return nil;
	} else {
		return [nickUserHost subdataWithRange:[nickUserHost rangeAfterRange:rangeOfUserHostSeparator]];
	}
}

// TODO: implement color support
-(NSData *) colorConvertToMIRC:(NSData *)message {
	NSMutableData *workingCopy = [message mutableCopy];

	[@[ @[ @"[B]", @"[/B]", [NSData dataFromCString:"\x02"] ],
		@[ @"[I]", @"[/I]", [NSData dataFromCString:"\x16"] ],
		@[ @"[U]", @"[/U]", [NSData dataFromCString:"\x1F"] ] ] forEach:^(NSArray *tags) {
			NSData *openingTag = [tags[0] dataUsingEncoding:self.encoding];
			NSData *closingTag = [tags[1] dataUsingEncoding:self.encoding];
			NSData *mircCode = tags[2];

			NSRange rangeOfOpeningTag, rangeOfClosingTag;
			do {
				// Find next opening tag.
				rangeOfOpeningTag = [workingCopy rangeOfData:openingTag
													 options:(NSDataSearchOptions) 0
													   range:workingCopy.fullRange];
				if (rangeOfOpeningTag.location != NSNotFound) {
					// Replace opening tag.
					[workingCopy replaceBytesInRange:rangeOfOpeningTag
										   withBytes:mircCode.bytes
											  length:mircCode.length];

					// Find next closing tag.
					rangeOfClosingTag = [workingCopy rangeOfData:closingTag
														 options:(NSDataSearchOptions) 0
														   range:[workingCopy rangeAfterRange:NSMakeRange(rangeOfOpeningTag.location,
																										  mircCode.length)]];
					if (rangeOfClosingTag.location != NSNotFound) {
						// Replace closing tag, if any.
						[workingCopy replaceBytesInRange:rangeOfClosingTag
											   withBytes:mircCode.bytes
												  length:mircCode.length];
					} else {
						// Otherwise, end the string with a closing tag.
						[workingCopy appendBytes:mircCode.bytes
										  length:mircCode.length];
					}
				}
			} while (rangeOfOpeningTag.location != NSNotFound);

			// Clean up stray closing tags.
			do {
				rangeOfClosingTag = [workingCopy rangeOfData:closingTag
													 options:(NSDataSearchOptions) 0
													   range:workingCopy.fullRange];
				if (rangeOfClosingTag.location != NSNotFound) {
					[workingCopy replaceBytesInRange:rangeOfClosingTag
										   withBytes:mircCode.bytes
											  length:mircCode.length];
				}
			} while (rangeOfClosingTag.location != NSNotFound);
		}];

	return [workingCopy copy];
}

-(NSData *) colorConvertFromMIRC:(NSData *)message {
	// TODO: Implement this for real!
	return [self colorStripFromMIRC:message];
}

// TODO: implement this!
-(NSData *) colorStripFromMIRC:(NSData *)message {
	return message;
}

/*************************************/
#pragma mark - Class methods (private)
/*************************************/

+(void) loadNumericCodes {
	NSString* numericCodeListPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IRC_Numerics"
																					 ofType:@"plist"];
	ircNumericCodeList = [NSDictionary dictionaryWithContentsOfFile:numericCodeListPath];
	if (ircNumericCodeList) {
		NSLog(@"IRC numeric codes list loaded successfully.\n");
	} else {
		NSLog(@"Could not load IRC numeric codes list!\n");
	}
}

/******************************/
#pragma mark - NSStreamDelegate
/******************************/

-(void) stream:(NSStream *)stream
   handleEvent:(NSStreamEvent)eventCode {
	switch (eventCode) {
		case NSStreamEventNone: {
			NSLog(@"NSStreamEventNone");

			break;
		}
		case NSStreamEventOpenCompleted: {
			NSLog(@"NSStreamEventOpenCompleted");
			dispatch_async(_q, ^{
				_stateFlags |= IRCClientSessionConnected;
			});

			break;
		}
		case NSStreamEventHasBytesAvailable: {
			NSLog(@"NSStreamEventHasBytesAvailable");
			dispatch_async(_q, ^{
				[self receiveData:((NSInputStream *) stream)];
			});

			break;
		}
		case NSStreamEventHasSpaceAvailable: {
			NSLog(@"NSStreamEventHasSpaceAvailable");
			dispatch_async(_q, ^{
				if (_dataToSend.length > 0)
					[self sendData:((NSOutputStream *) stream)];
			});

			break;
		}
		case NSStreamEventErrorOccurred: {
			NSLog(@"NSStreamEventErrorOccurred");
			NSLog(@"%@", stream.streamError);
			dispatch_async(_q, ^{
				[self disconnect];
			});

			break;
		}
		case NSStreamEventEndEncountered: {
			NSLog(@"NSStreamEventEndEncountered");
			dispatch_async(_q, ^{
				[self disconnect];
			});

			break;
		}
	}
}

/****************************/
#pragma mark - Helper methods
/****************************/

-(void) sendData:(NSOutputStream *)stream {
	if (self.isConnected == NO)
		return;

	// Copy up to 512 bytes of data into a buffer.
	NSUInteger bufferSize = (_dataToSend.length < 512
							 ? _dataToSend.length
							 : 512);
	uint8_t buffer[bufferSize];
	[_dataToSend getBytes:buffer
				   length:bufferSize];

	// Write the buffer to the stream.
	NSInteger bytesWritten = [stream write:buffer
								 maxLength:bufferSize];

	if (bytesWritten < 0) {
		NSLog(@"%@", stream.streamError);
		[self disconnect];
	} else {
		// Discard the sent bytes.
		[_dataToSend replaceBytesInRange:NSRangeMake(0, ((NSUInteger) bytesWritten))
							   withBytes:NULL
								  length:0];
	}
}

-(void) receiveData:(NSInputStream *)stream {
	if (self.isConnected == NO)
		return;

	// Get some bytes from the stream.
	NSUInteger bufferSize = 512;
	uint8_t buffer[bufferSize];
	NSInteger bytesRead = [stream read:buffer
							 maxLength:bufferSize];

	if (bytesRead < 0) {
		NSLog(@"%@", stream.streamError);
		[self disconnect];
	} else if (bytesRead == 0) {
		NSLog(@"0 bytes read (end of stream encountered).");
		[self disconnect];
	} else {
		[_receivedData appendBytes:buffer
							length:((NSUInteger) bytesRead)];

		// If there’s one or more full messages in there, process them.
		// (Otherwise, we’ll try again when more bytes have come in.)
		NSRange crlfRange = NSRangeZero();
		while (crlfRange.location != NSNotFound) {
			crlfRange = [_receivedData rangeOfBytes:C_string_crlf
											options:(NSDataSearchOptions) 0
											  range:_receivedData.fullRange];
			if (crlfRange.location != NSNotFound) {
				NSRange messageRange = NSRangeMake(0, NSRangeMax(crlfRange));
				[self handleReceivedMessage:[_receivedData subdataWithRange:messageRange]];
				[_receivedData replaceBytesInRange:messageRange
										 withBytes:NULL
											length:0];
			}
		}
	}
}

-(void) handleReceivedMessage:(NSData *)messageData {
	NSLog(@"handleReceivedMessage: [%s]", messageData.terminatedCString);
	NSData *prefix;
	NSData *command;
	NSMutableArray <NSData *> *params = [NSMutableArray array];

	/******************************/
	/* State machine based parsing.
	 */

	typedef NS_ENUM(NSUInteger, IRCClientMessageParsingSection) {
		IRCClientMessageParsingStart,
		IRCClientMessageParsingPrefix,
		IRCClientMessageParsingCommand,
		IRCClientMessageParsingMiddleParams,
		IRCClientMessageParsingTrailingParam,
		IRCClientMessageParsingEnd
	};

	IRCClientMessageParsingSection section = IRCClientMessageParsingStart;
	NSUInteger sectionStart = 0;
	for (NSUInteger i = 0; i < messageData.length; i++) {
		char c = ((char *)(messageData.bytes))[i];
		switch (section) {
			case IRCClientMessageParsingStart:
				if (c == ':')
					sectionStart = (i + 1);
				section = (c == ':'
						   ? IRCClientMessageParsingPrefix
						   : IRCClientMessageParsingCommand);
				break;
			case IRCClientMessageParsingPrefix:
				if (c == ' ') {
					prefix = [messageData subdataWithRange:NSRangeMake(sectionStart,
																	   i - sectionStart)];
					sectionStart = (i + 1);
					section = IRCClientMessageParsingCommand;
				}
				break;
			case IRCClientMessageParsingCommand:
				if (c == ' ') {
					command = [messageData subdataWithRange:NSRangeMake(sectionStart,
																		i - sectionStart)];
					sectionStart = (i + 1);
					section = IRCClientMessageParsingMiddleParams;
				}
				break;
			case IRCClientMessageParsingMiddleParams:
				if (c == ' ') {
					[params addObject:[messageData subdataWithRange:NSRangeMake(sectionStart,
																				i - sectionStart)]];
					sectionStart = (i + 1);
				} else if (c == ':') {
					sectionStart = (i + 1);
					section = IRCClientMessageParsingTrailingParam;
				} else if (   ((char *)(messageData.bytes))[i]     == '\r'
						   && ((char *)(messageData.bytes))[i + 1] == '\n') {
					[params addObject:[messageData subdataWithRange:NSRangeMake(sectionStart,
																				i - sectionStart)]];
					section = IRCClientMessageParsingEnd;
				}
				break;
			case IRCClientMessageParsingTrailingParam:
				if (   ((char *)(messageData.bytes))[i]     == '\r'
					&& ((char *)(messageData.bytes))[i + 1] == '\n') {
					[params addObject:[messageData subdataWithRange:NSRangeMake(sectionStart,
																				i - sectionStart)]];
					section = IRCClientMessageParsingEnd;
				}
				break;
			case IRCClientMessageParsingEnd:
				break;
		}
	}

	NSMutableArray <NSData *> *parts = [NSMutableArray array];
	[parts addObject:(prefix ?: [NSData data])];
	[parts addObject:command];
	[parts addObjectsFromArray:params];
	NSLog(@"[%@]", [[parts map:^NSString *(NSData *part) {
		return [NSString stringWithFormat:@"%s", part.terminatedCString];
	}] componentsJoinedByString:@"]["]);

	[self handleIRCEvent:command
					from:prefix
				  params:params];

	/**********************/
	/* Range-based parsing.
	 */

//	NSData *colon = [NSData dataFromCString:":"];
//	NSData *space = [NSData dataFromCString:" "];
//	NSData *crlf = [NSData dataFromCString:C_string_crlf];
//
//	NSRange remainder = messageData.fullRange;
//	NSRange spaceRange;
//	NSRange maybeColonRange;
//
//	// Prefix.
//	maybeColonRange = NSRangeMake(remainder.location,
//								  colon.length);
//	if ([[messageData subdataWithRange:maybeColonRange] isEqualToData:colon]) {
//		remainder = [messageData rangeAfterRange:maybeColonRange];
//		spaceRange = [messageData rangeOfData:space
//									  options:(NSDataSearchOptions) 0
//										range:remainder];
//		prefix = [messageData subdataWithRange:NSRangeMake(remainder.location,
//														   spaceRange.location - remainder.location)];
//		remainder = [messageData rangeAfterRange:spaceRange];
//	}
//
//	// Command.
//	spaceRange = [messageData rangeOfData:space
//								  options:(NSDataSearchOptions) 0
//									range:remainder];
//	command = [messageData subdataWithRange:NSRangeMake(remainder.location,
//														spaceRange.location - remainder.location)];
//	remainder = [messageData rangeAfterRange:spaceRange];
//
//	// Params.
//	while (YES) {
//		maybeColonRange = NSRangeMake(remainder.location,
//									  colon.length);
//		if ([[messageData subdataWithRange:maybeColonRange] isEqualToData:colon]) {
//			// Trailing param.
//			remainder = [messageData rangeAfterRange:maybeColonRange];
//			NSRange crlfRange = [messageData rangeOfData:crlf
//												 options:(NSDataSearchOptions) 0
//												   range:remainder];
//			[params addObject:[messageData subdataWithRange:NSRangeMake(remainder.location,
//																		crlfRange.location - remainder.location)]];
//			break;
//		} else {
//			// Middle params.
//			spaceRange = [messageData rangeOfData:space
//										  options:(NSDataSearchOptions) 0
//											range:remainder];
//			if (spaceRange.location == NSNotFound) {
//				NSRange crlfRange = [messageData rangeOfData:crlf
//													 options:(NSDataSearchOptions) 0
//													   range:remainder];
//				[params addObject:[messageData subdataWithRange:NSRangeMake(remainder.location,
//																			crlfRange.location - remainder.location)]];
//				break;
//			} else {
//				[params addObject: [messageData subdataWithRange:NSRangeMake(remainder.location,
//																			 spaceRange.location - remainder.location)]];
//				remainder = [messageData rangeAfterRange:spaceRange];
//				if ([[messageData subdataWithRange:remainder] isEqualToData:crlf])
//					break;
//			}
//		}
//	}
//
//	[self handleIRCEvent:command
//					from:prefix
//				  params:params];
}

-(void) openStream:(NSStream *)stream {
	[stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
					  forMode:NSDefaultRunLoopMode];
	[stream open];
}

-(void) closeStream:(NSStream *)stream {
	[stream close];
	[stream removeFromRunLoop:[NSRunLoop currentRunLoop]
					  forMode:NSDefaultRunLoopMode];
}

/******************************/
#pragma mark - Instance methods
/******************************/

-(int) connect {
	if (self.isConnected)
		return 0;

	NSInputStream *iStream;
	NSOutputStream *oStream;
	[NSStream getStreamsToHostNamed:[NSString stringWithUTF8Data:_server]
							   port:_port
						inputStream:&iStream
					   outputStream:&oStream];
	_iStream = iStream;
	_oStream = oStream;

	_receivedData = [NSMutableData data];
	_dataToSend = [NSMutableData data];

	// Prepare cleanup handler.
	__unsafe_unretained typeof(self) weakSelf = self;
	_cleanupHandler = ^void() {
		_stateFlags = (IRCClientSessionStateFlags) 0;

		[weakSelf closeStream:iStream];
		[weakSelf closeStream:oStream];

		_iStream = nil;
		_oStream = nil;

		_receivedData = nil;
		_dataToSend = nil;
		
		_cleanupHandler = nil;
	};

	// Get proxy settings from system configuration.
	NSDictionary *proxySettings = CFBridgingRelease(CFNetworkCopySystemProxySettings());
	BOOL SOCKSProxyEnabled = ([proxySettings[(NSString *) kCFNetworkProxiesSOCKSEnable] integerValue] != 0);

	// TODO: Allow setting this somehow!
	BOOL SSLEnabled = NO;

	// Configure and open streams.
	[@[ iStream, oStream ] forEach:^(NSStream *stream) {
		[stream setDelegate:self];
		if (SSLEnabled)
			[stream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
						 forKey:NSStreamSocketSecurityLevelKey];
		if (SOCKSProxyEnabled)
			[stream setProperty:proxySettings
						 forKey:NSStreamSOCKSProxyConfigurationKey];
		[self openStream:stream];
	}];

	// Send PASS message (if need be).
	if (   _password
		&& _password.length > 0) {
		[self sendRaw:[NSData dataWithFormat:"PASS %@", _password, nil]];
	}

	// Send NICK message.
	[self sendRaw:[NSData dataWithFormat:"NICK %@", _nickname, nil]];

	// Send USER message.
	[self sendRaw:[NSData dataWithFormat:"USER %@ unknown unknown :%@", _username, _realname, nil]];

	return 1;
}

-(void) disconnect {
	if (self.isConnected) {
		[_delegate disconnected:self];
		_cleanupHandler();
	}
}

-(BOOL) setNickname:(NSData *)nickname
		   username:(NSData *)username
		   realname:(NSData *)realname {
	if (self.isConnected) {
		return NO;
	} else {
		_nickname = nickname;
		_username = username;
		_realname = realname;
		
		return YES;
	}
}

/**************************/
#pragma mark - IRC commands
/**************************/

-(int) sendRaw:(NSData *)message {
	dispatch_async(_q, ^{
		[_dataToSend appendData:message];
		[_dataToSend appendBytes:C_string_crlf
						  length:2];

		if ([_oStream hasSpaceAvailable])
			[self sendData:_oStream];
	});

	return 0;
}

-(int) quit:(NSData *)reason {
	[self sendRaw:[NSData dataWithFormat:"QUIT :%@", (reason ?: [NSData dataFromCString:"quit"]), nil]];

	return 0;
}

-(int) join:(NSData *)channel 
		key:(NSData *)key {
	if (  !channel
		|| channel.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	if (   key
		&& key.length > 0)
		[self sendRaw:[NSData dataWithFormat:"JOIN %@ :%@", channel, key, nil]];
	else
		[self sendRaw:[NSData dataWithFormat:"JOIN %@", channel, nil]];

	return 0;
}

-(int) names:(NSData *)channel {
	if (channel)
		[self sendRaw:[NSData dataWithFormat:"NAMES %@", channel, nil]];
	else
		[self sendRaw:[NSData dataWithFormat:"NAMES", nil]];

	return 0;
}

-(int) list:(NSData *)channel {
	if (channel)
		[self sendRaw:[NSData dataWithFormat:"LIST %@", channel, nil]];
	else
		[self sendRaw:[NSData dataWithFormat:"LIST", nil]];

	return 0;
}

-(int) userMode:(NSData *)mode {
	if (mode)
		[self sendRaw:[NSData dataWithFormat:"MODE %@ %@", _nickname, mode, nil]];
	else
		[self sendRaw:[NSData dataWithFormat:"MODE %@", _nickname, nil]];

	return 0;
}

-(int) nick:(NSData *)newnick {
	if (  !newnick
		|| newnick.length == 0)
		return 1;
//		return LIBIRC_ERR_INVAL;

	[self sendRaw:[NSData dataWithFormat:"NICK %@", newnick, nil]];

	return 0;
}

-(int) who:(NSData *)nickmask {
	if (  !nickmask
		|| nickmask.length == 0)
		return 1;
//		return LIBIRC_ERR_INVAL;

	[self sendRaw:[NSData dataWithFormat:"WHO %@", nickmask, nil]];

	return 0;
}

-(int) whois:(NSData *)nick {
	if (!nick || nick.length == 0)
		return 1;
//		return LIBIRC_ERR_INVAL;

	[self sendRaw:[NSData dataWithFormat:"WHOIS %@", nick, nil]];

	return 0;
}

-(int) message:(NSData *)message 
			to:(NSData *)target {
	if (   !target  || target.length == 0
		|| !message || message.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[self sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :%@", target, [self colorConvertToMIRC:message], nil]];

	return 0;
}

-(int) action:(NSData *)action
		   to:(NSData *)target {
	if (   !target || target.length == 0
		|| !action || action.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[self sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :\x01" "ACTION %@\x01", target, [self colorConvertToMIRC:action], nil]];

	return 0;
}

-(int) notice:(NSData *)notice 
		   to:(NSData *)target {
	if (   !target || target.length == 0
		|| !notice || notice.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[self sendRaw:[NSData dataWithFormat:"NOTICE %@ :%@", target, notice, nil]];

	return 0;
}

-(int) ctcpRequest:(NSData *)request 
			target:(NSData *)target {
	if (   !target  || target.length == 0
		|| !request || request.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[self sendRaw:[NSData dataWithFormat:"PRIVMSG %@ :\x01%@\x01", target, request, nil]];
	return 0;
}

-(int) ctcpReply:(NSData *)reply 
		  target:(NSData *)target {
	if (   !target || target.length == 0
		|| !reply  || reply.length == 0)
		return 1;
//		return LIBIRC_ERR_STATE;

	[self sendRaw:[NSData dataWithFormat:"NOTICE %@ :\x01%@\x01", target, reply, nil]];
	return 0;
}

/********************************/
#pragma mark - IRC event handlers
/********************************/

-(NSData *) CTCPContent:(NSData *)messageBody {
	NSData *ctcpQuote = [NSData dataFromCString:"\x01"];
	if (messageBody.length > 1
		&& [[messageBody subdataWithRange:NSRangeMake(0, 1)] isEqualToData:ctcpQuote]
		&& [[messageBody subdataWithRange:NSRangeMake(messageBody.length - 1, 1)] isEqualToData:ctcpQuote]) {
		return [messageBody subdataWithRange:NSRangeMake(1, messageBody.length - 2)];
	} else {
		return nil;
	}
}

-(NSData *) processColorCodes:(NSData *)messageBody {
	typedef NS_ENUM(NSUInteger, SA_IRC_ColorCodeHandling) {
		SA_IRC_ParseColorCodes,
		SA_IRC_StripColorCodes,
		SA_IRC_IgnoreColorCodes,
	};

	// TODO: Support setting this somehow...
	SA_IRC_ColorCodeHandling whatAboutColors = SA_IRC_ParseColorCodes;

	switch (whatAboutColors) {
		case SA_IRC_IgnoreColorCodes:
			return messageBody;
		case SA_IRC_ParseColorCodes:
			return [self colorConvertFromMIRC:messageBody];
		case SA_IRC_StripColorCodes:
			return [self colorStripFromMIRC:messageBody];
	}
}

-(void) handleIRCEvent:(NSData *)command
				  from:(NSData *)origin
				params:(NSArray <NSData *> *)params {
	// This is so we can refer to “param [ 0 / 1 / 2 ] or nil” without
	// having to check for out-of-range every time.
	NSData *param_0 = (params.count > 0
					   ? params[0]
					   : nil);
	NSData *param_1 = (params.count > 1
					   ? params[1]
					   : nil);
	NSData *param_2 = (params.count > 2
					   ? params[2]
					   : nil);

	// PING event.
	if ([command isEqualToCString:"PING"]) {
		// TODO: implement an "ignore ping" toggle
		// and a "ping passthrough" toggle
		[self sendRaw:[NSData dataWithFormat:"PONG %@", param_0, nil]];

		if ([_delegate respondsToSelector:@selector(ping:from:session:)]) {
			[_delegate ping:param_0
					   from:origin
					session:self];
		}

		return;
	}

	// Numeric event.
	if (   command.length == 3
		&& isdigit(((char *) command.bytes)[0])
		&& isdigit(((char *) command.bytes)[1])
		&& isdigit(((char *) command.bytes)[2])) {
		NSUInteger numericEventCode = (NSUInteger) atoi(command.terminatedCString);

		// RPL_WELCOME, RPL_ENDOFMOTD, or ERR_NOMOTD.
		if (   (   numericEventCode == 1
				|| numericEventCode == 376
				|| numericEventCode == 422)
			&& !(_stateFlags & IRCClientSessionMOTDReceived)) {
			_stateFlags |= IRCClientSessionMOTDReceived;
			[_delegate connectionSucceeded:self];
		}

		if ([_delegate respondsToSelector:@selector(numericEventReceived:from:params:session:)]) {
			[_delegate numericEventReceived:numericEventCode
									   from:origin
									 params:params
									session:self];
		}

		return;
	}

	// IRC command.
	if ([command isEqualToCString:"NICK"]) {
		/*!
		 * The ‘nick’ event is triggered when the client receives a NICK message,
		 * meaning that someone (including you) on a channel with the client has
		 * changed their nickname.
		 *
		 * \param origin The person who changed their nick. Note that it can be you!
		 * \param params[0] Mandatory; contains the new nick.
		 */
		[self nickChangedFrom:origin
						   to:param_0];
	} else if ([command isEqualToCString:"QUIT"]) {
		/*!
		 * The ‘quit’ event is triggered upon receipt of a QUIT message, which
		 * means that someone on a channel with the client has disconnected.
		 *
		 * \param origin The person who is disconnected.
		 * \param params[0] Optional; contains the reason message (user-specified).
		 */
		[_delegate userQuit:origin
				 withReason:param_0
					session:self];
	} else if ([command isEqualToCString:"JOIN"]) {
		/*!
		 * The ‘join’ event is triggered upon receipt of a JOIN message, which
		 * means that someone has entered a channel that the client is on.
		 *
		 * \param origin The person who joined the channel. By comparing it with
		 *               your own nickname, you can check whether your JOIN
		 *               command succeed.
		 * \param params[0] Mandatory; contains the channel name.
		 */
		[self userJoined:origin
				 channel:param_0];
	} else if ([command isEqualToCString:"PART"]) {
		/*!
		 * The ‘part’ event is triggered upon receipt of a PART message, which
		 * means that someone has left a channel that the client is on.
		 *
		 * \param Origin The person who left the channel. By comparing it with
		 *               your own nickname, you can check whether your PART
		 *               command succeed.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the reason message (user-defined).
		 */
		[self userParted:origin
				 channel:param_0
			  withReason:param_1];
	} else if ([command isEqualToCString:"MODE"]) {
		if (   param_0
			&& [param_0 isEqualToData:_nickname]) {
			/*!
			 * The ‘umode’ event is triggered upon receipt of a user MODE message,
			 * which means that your user mode has been changed.
			 *
			 * \param origin The person who changed the user mode.
			 * \param params[0] Mandatory; contains the user changed mode, like
			 *        ‘+t’, ‘-i’ and so on.
			 */
			[_delegate modeSet:param_1
							by:origin
					   session:self];
		} else {
			/*!
			 * The ‘mode’ event is triggered upon receipt of a channel MODE message,
			 * which means that someone on a channel with the client has changed the
			 * channel’s parameters.
			 *
			 * \param origin The person who changed the channel mode.
			 * \param params[0] Mandatory; contains the channel name.
			 * \param params[1] Mandatory; contains the changed channel mode, like
			 *        ‘+t’, ‘-i’, and so on.
			 * \param params[2] Optional; contains the mode argument (for example, a
			 *      key for +k mode, or user who got channel operator status for
			 *      +o mode)
			 */
			IRCClientChannel *channel = _channels[param_0];
			[channel modeSet:param_1
				  withParams:param_2
						  by:origin];
		}
	} else if ([command isEqualToCString:"TOPIC"]) {
		/*!
		 * The ‘topic’ event is triggered upon receipt of a TOPIC message, which
		 * means that someone on a channel with the client has changed the
		 * channel’s topic.
		 *
		 * \param origin The person who changes the channel topic.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the new topic.
		 */
		IRCClientChannel *channel = _channels[param_0];
		[channel topicSet:param_1
					   by:origin];
	} else if ([command isEqualToCString:"KICK"]) {
		/*!
		 * The ‘kick’ event is triggered upon receipt of a KICK message, which
		 * means that someone on a channel with the client (or possibly the
		 * client itself!) has been forcibly ejected.
		 *
		 * \param origin The person who kicked the poor victim.
		 * \param params[0] Mandatory; contains the channel name.
		 * \param params[1] Optional; contains the nick of kicked person.
		 * \param params[2] Optional; contains the kick text.
		 */
		[self userKicked:param_1
			 fromChannel:param_0
					  by:origin
			  withReason:param_2];
	} else if ([command isEqualToCString:"ERROR"]) {
		/*!
		 * The ‘error’ event is triggered upon receipt of an ERROR message, which
		 * (when sent to clients) usually means the client has been disconnected.
		 *
		 * \param origin the person, who generates the message.
		 * \param params optional, contains who knows what.
		 */
		[_delegate errorReceived:params
						 session:self];
	} else if ([command isEqualToCString:"INVITE"]) {
		/*!
		 * The ‘invite’ event is triggered upon receipt of an INVITE message,
		 * which means that someone is permitting the client’s entry into a +i
		 * channel.
		 *
		 * \param origin The person who INVITEd you.
		 * \param params[0] Mandatory; contains your nick.
		 * \param params[1] Mandatory; contains the channel name you’re invited into.
		 *
		 * \sa irc_cmd_invite irc_cmd_chanmode_invite
		 */
		[_delegate invitedToChannel:param_1
								 by:origin
							session:self];
	} else if ([command isEqualToCString:"PRIVMSG"]) {
		NSData *ctcpContent = [self CTCPContent:param_1];
		if (ctcpContent) {
			NSData *dccPrefix = [NSData dataFromCString:"DCC "];
			NSData *actionPrefix = [NSData dataFromCString:"ACTION "];
			if ([[ctcpContent subdataWithRange:NSRangeMake(0, dccPrefix.length)] isEqualToData:dccPrefix]) {
				// TODO: implement DCC request support!
			} else if ([[ctcpContent subdataWithRange:NSRangeMake(0, actionPrefix.length)] isEqualToData:actionPrefix]) {
				NSData *action = [self processColorCodes:[ctcpContent
														  subdataWithRange:[ctcpContent
																			rangeAfterRange:NSRangeMake(0, actionPrefix.length)]]];
				/*!
				 * The ‘action’ event is triggered when the client receives the CTCP
				 * ACTION message. These messages usually looks like:\n
				 * \code
				 * [23:32:55] * Tim gonna sleep.
				 * \endcode
				 *
				 * \param origin The person who generated the message.
				 * \param params[0] Mandatory; the target of the message.
				 * \param params[1] Mandatory; the ACTION message.
				 */
				IRCClientChannel* channel = _channels[param_0];
				if (channel != nil) {
					// An action on a channel we’re on.
					[channel actionPerformed:action
									  byUser:origin];
				} else {
					// An action in a private message.
					[_delegate privateCTCPActionReceived:action
												fromUser:origin
												 session:self];
				}
			} else {
				/*!
				 * The ‘ctcp’ event is triggered when the client receives the CTCP
				 * request. By default, the built-in CTCP request handler is used. The
				 * build-in handler automatically replies on most CTCP messages, so you
				 * will rarely need to override it.
				 *
				 * \param origin The person who generated the message.
				 * \param params[0] Mandatory; contains the complete CTCP message, including
				 *                  its arguments.
				 *
				 * Mirc generates PING, FINGER, VERSION, TIME and ACTION messages,
				 * check the source code of \c libirc_event_ctcp_internal function to
				 * see how to write your own CTCP request handler. Also you may find
				 * useful this question in FAQ: \ref faq4
				 */
				[self CTCPRequestReceived:ctcpContent
								 fromUser:origin];
			}
		} else if ([param_0 isEqualToData:_nickname]) {
			/*!
			 * The ‘privmsg’ event is triggered upon receipt of a PRIVMSG message
			 * which is addressed to one or more clients, which means that someone
			 * is sending the client a private message.
			 *
			 * \param origin The person who generated the message.
			 * \param params[0] Mandatory; contains your nick.
			 * \param params[1] Optional; contains the message text.
			 */
			NSData *message = [self processColorCodes:param_1];
			[_delegate privateMessageReceived:message
									 fromUser:origin
									  session:self];
		} else if (   ((char *) param_0.bytes)[0] == '#'
				   || ((char *) param_0.bytes)[0] == '&'
				   || ((char *) param_0.bytes)[0] == '!'
				   || ((char *) param_0.bytes)[0] == '+') {
			/*!
			 * The ‘chanmsg’ event is triggered upon receipt of a PRIVMSG message
			 * to an entire channel, which means that someone on a channel with
			 * the client has said something aloud. Your own messages don’t trigger
			 * PRIVMSG event.
			 *
			 * \param origin The person who generated the message.
			 * \param params[0] Mandatory; contains the channel name.
			 * \param params[1] Optional; contains the message text.
			 */
			IRCClientChannel *channel = _channels[param_0];
			NSData *message = [self processColorCodes:param_1];
			[channel messageSent:message
						  byUser:origin];
		} else {
			/*!
			 * The ‘servmsg’ event is triggered upon receipt of a PRIVMSG message
			 * which is addressed to no one in particular, but it sent to the client
			 * anyway.
			 *
			 * \param origin The person who generated the message.
			 * \param params Optional; contains who knows what.
			 */
			params = [params map:^id(NSData *param) {
				return [self processColorCodes:param];
			}];
			[_delegate serverMessageReceivedFrom:origin
										  params:params
										 session:self];
		}
	} else if ([command isEqualToCString:"NOTICE"]) {
		NSData *ctcpContent = [self CTCPContent:param_1];
		if (ctcpContent) {
			/*!
			 * The ‘ctcp’ event is triggered when the client receives the CTCP reply.
			 *
			 * \param origin The person who generated the message.
			 * \param params[0] Mandatory; the CTCP message itself with its arguments.
			 */
			if ([_delegate respondsToSelector:@selector(CTCPReplyReceived:fromUser:session:)]) {
				[_delegate CTCPReplyReceived:param_0
									fromUser:origin
									 session:self];
			}
		} else if ([param_0 isEqualToData:_nickname]) {
			/*!
			 * The ‘notice’ event is triggered upon receipt of a NOTICE message
			 * which means that someone has sent the client a public or private
			 * notice. According to RFC 1459, the only difference between NOTICE
			 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
			 * messages. Unfortunately, this rule is frequently violated by IRC
			 * servers itself - for example, NICKSERV messages require reply, and
			 * are NOTICEs.
			 *
			 * \param origin The person who generated the message.
			 * \param params[0] Mandatory; contains your nick.
			 * \param params[1] Optional; contains the message text.
			 */
			NSData *notice = [self processColorCodes:param_1];
			[_delegate privateNoticeReceived:notice
									fromUser:origin
									 session:self];
		} else if (   ((char *) param_0.bytes)[0] == '#'
				   || ((char *) param_0.bytes)[0] == '&'
				   || ((char *) param_0.bytes)[0] == '!'
				   || ((char *) param_0.bytes)[0] == '+') {
			/*!
			 * The ‘notice’ event is triggered upon receipt of a NOTICE message
			 * which means that someone has sent the client a public or private
			 * notice. According to RFC 1459, the only difference between NOTICE
			 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
			 * messages. Unfortunately, this rule is frequently violated by IRC
			 * servers itself - for example, NICKSERV messages require reply, and
			 * are NOTICEs.
			 *
			 * \param origin The person who generated the message.
			 * \param params[0] Mandatory; contains the target channel name.
			 * \param params[1] Optional; contains the message text.
			 */
			IRCClientChannel *channel = _channels[param_0];
			NSData *notice = [self processColorCodes:param_1];
			[channel noticeSent:notice
						 byUser:origin];
		} else {
			/*!
			 * The ‘server_notice’ event is triggered upon receipt of a NOTICE
			 * message which means that the server has sent the client a notice.
			 * This notice is not necessarily addressed to the client’s nick
			 * (for example, AUTH notices, sent before the client’s nick is known).
			 * According to RFC 1459, the only difference between NOTICE
			 * and PRIVMSG is that you should NEVER automatically reply to NOTICE
			 * messages. Unfortunately, this rule is frequently violated by IRC
			 * servers itself - for example, NICKSERV messages require reply, and
			 * are NOTICEs.
			 *
			 * \param origin The person who generated the message.
			 * \param params Optional; contains who knows what.
			 */
			params = [params map:^id(NSData *param) {
				return [self processColorCodes:param];
			}];
			[_delegate serverNoticeReceivedFrom:origin
										 params:params
										session:self];
		}
	} else {
		/*!
		 * The ‘unknown’ event is triggered upon receipt of any number of
		 * unclassifiable miscellaneous messages, which aren’t handled by the
		 * library.
		 */
		if ([_delegate respondsToSelector:@selector(unknownEventReceived:from:params:session:)]) {
			[_delegate unknownEventReceived:command
									   from:origin
									 params:params
									session:self];
		}
	}
}

/******************************************/
#pragma mark - Event handler helper methods
/******************************************/

-(void) nickChangedFrom:(NSData *)oldNick
					 to:(NSData *)newNick {
	NSData* oldNickOnly = [IRCClientSession nickFromNickUserHost:oldNick];
	
	if ([_nickname isEqualToData:oldNickOnly]) {
		_nickname = newNick;
		[_delegate nickChangedFrom:oldNickOnly
								to:newNick 
							   own:YES 
						   session:self];
	} else {
		[_delegate nickChangedFrom:oldNickOnly 
								to:newNick 
							   own:NO 
						   session:self];
	}
}

-(void) userJoined:(NSData *)nick
		   channel:(NSData *)channelName {
	NSData* nickOnly = [IRCClientSession nickFromNickUserHost:nick];
	
	if ([_nickname isEqualToData:nickOnly]) {
		// We just joined a channel; allocate an IRCClientChannel object and
		// add it to our channels list.

		IRCClientChannel* newChannel = [[IRCClientChannel alloc] initWithName:channelName
																andIRCSession:self];
		_channels[channelName] = newChannel;
		[_delegate joinedNewChannel:newChannel 
							session:self];
	} else {
		// Someone joined a channel we’re on.
		
		IRCClientChannel* channel = _channels[channelName];
		[channel userJoined:nick];
	}
}

-(void) userParted:(NSData *)nick 
		   channel:(NSData *)channelName 
		withReason:(NSData *)reason {
	IRCClientChannel* channel = _channels[channelName];
	
	NSData* nickOnly = [IRCClientSession nickFromNickUserHost:nick];
	
	if ([_nickname isEqualToData:nickOnly]) {
		// We just left a channel; remove it from the channels dict.

		[_channels removeObjectForKey:channelName];
		[channel userParted:nick 
				 withReason:reason 
						 us:YES];
	} else {
		[channel userParted:nick 
				 withReason:reason 
						 us:NO];
	}
}

-(void) userKicked:(NSData *)nick 
	   fromChannel:(NSData *)channelName 
				by:(NSData *)byNick 
		withReason:(NSData *)reason {
	IRCClientChannel* channel = _channels[channelName];

	if (nick == nil) {
		// we got kicked from a channel we’re on :(
		[_channels removeObjectForKey:channelName];
		[channel userKicked:_nickname 
				 withReason:reason 
						 by:byNick 
						 us:YES];
	} else {
		// Someone else got booted from a channel we’re on.
		[channel userKicked:nick 
				 withReason:reason 
						 by:byNick 
						 us:NO];
	}
}

/*****************************************/
#pragma mark - CTCP request handler helper
/*****************************************/

-(void) CTCPRequestReceived:(NSData *)request 
				   fromUser:(NSData *)nick {
	NSData *nickOnly = [IRCClientSession nickFromNickUserHost:nick];

	if ([request isEqualToCString:"PING"]) {
		[self ctcpReply:request
				 target:nickOnly];
	} else if ([request isEqualToCString:"VERSION"]) {
		[self ctcpReply:[NSData dataWithFormat:"VERSION %@", _version, nil]
				 target:nickOnly];
	} else if ([request isEqualToCString:"FINGER"]) {
		[self ctcpReply:[NSData dataWithFormat:"FINGER %s (%s) Idle 0 seconds)", _username, _realname, nil]
				 target:nickOnly];
	} else if ([request isEqualToCString:"TIME"]) {
		time_t current_time;
		char timestamp[40];
		struct tm *time_info;
		
		time(&current_time);
		time_info = localtime(&current_time);
		
		strftime(timestamp, 40, "TIME %a %b %e %H:%M:%S %Z %Y", time_info);
		
		[self ctcpReply:[NSData dataFromCString:timestamp]
				 target:nickOnly];
	} else {
		if ([_delegate respondsToSelector:@selector(CTCPRequestReceived:ofType:fromUser:session:)]) {
			NSData *space = [NSData dataFromCString:" "];
			NSRange rangeOfFirstSpace = [request rangeOfData:space
													 options:(NSDataSearchOptions) 0
													   range:request.fullRange];

			NSRange rangeOfSecondSpace = (rangeOfFirstSpace.location != NSNotFound
										  ? [request rangeOfData:space
														  options:(NSDataSearchOptions) 0
															range:[request rangeAfterRange:rangeOfFirstSpace]]
										  : NSRangeMake(NSNotFound, 0));

			NSData *requestTypeData = (rangeOfFirstSpace.location != NSNotFound
									   ? [request subdataWithRange:NSRangeMake(0, rangeOfFirstSpace.location)]
									   : request);
			NSData *requestBodyData = (rangeOfSecondSpace.location != NSNotFound
									   ? [request subdataWithRange:NSRangeMake(rangeOfFirstSpace.location + space.length,
																			   rangeOfSecondSpace.location - (rangeOfFirstSpace.location + space.length))]
									   : nil);
			
			[_delegate CTCPRequestReceived:requestBodyData 
									ofType:requestTypeData 
								  fromUser:nick
								   session:self];
		}
	}
}

@end

/***********************************************/
#pragma mark - Callback function implementations
/***********************************************/


/*!
 * The ‘dcc chat’ event is triggered when someone requests a DCC CHAT from
 * you.
 *
 * \param session the session, which generates an event
 * \param nick    the person who requested DCC CHAT with you.
 * \param addr    the person's IP address in decimal-dot notation.
 * \param dccid   an id associated with this request. Use it in calls to
 *                irc_dcc_accept() or irc_dcc_decline().
 */
//static void onDCCChatRequest(irc_session_t *session,
//							 const char *nick,
//							 const char *addr,
//							 irc_dcc_t dccid) {
//	// TODO: figure out what to do here???
//}

/*!
 * The ‘dcc send’ event is triggered when someone wants to send a file
 * to you via DCC SEND request.
 *
 * \param session the session, which generates an event
 * \param nick    the person who requested DCC SEND to you.
 * \param addr    the person's IP address in decimal-dot notation.
 * \param filename the sent filename.
 * \param size    the filename size.
 * \param dccid   an id associated with this request. Use it in calls to
 *                irc_dcc_accept() or irc_dcc_decline().
 */
//static void onDCCSendRequest(irc_session_t *session,
//							 const char *nick,
//							 const char *addr,
//							 const char *filename,
//							 size_t size,
//							 irc_dcc_t dccid) {
//	// TODO: figure out what to do here???
//}
