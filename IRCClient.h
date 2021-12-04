//
//  IRCClient.h
//  IRCClient
//
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

#ifndef IRCCLIENT
#define IRCCLIENT

#import <Foundation/Foundation.h>

//! Project version number for IRCClient.
FOUNDATION_EXPORT double IRCClientVersionNumber;

//! Project version string for IRCClient.
FOUNDATION_EXPORT const unsigned char IRCClientVersionString[];

#import "IRCClient/IRCClientSession.h"
#import "IRCClient/IRCClientSessionDelegate.h"
#import "IRCClient/IRCClientChannel.h"
#import "IRCClient/IRCClientChannelDelegate.h"

#endif
