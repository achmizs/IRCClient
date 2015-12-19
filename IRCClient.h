//
//  IRCClient.h
//  IRCClient
//
//  Copyright © 2015 Said Achmiz.
//
/*
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

//! Project version number for IRCClient.
FOUNDATION_EXPORT double IRCClientVersionNumber;

//! Project version string for IRCClient.
FOUNDATION_EXPORT const unsigned char IRCClientVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <IRCClient/PublicHeader.h>

#import "IRCClient/IRCClientSession.h"
#import "IRCClient/IRCClientSessionDelegate.h"
#import "IRCClient/IRCClientChannel.h"
#import "IRCClient/IRCClientChannelDelegate.h"
