//
//  IRCClient.h
//
//  Modified IRCClient Copyright 2015-2021 Said Achmiz.
//  Original IRCClient Copyright 2009 Nathan Ollerenshaw.
//  libircclient Copyright 2004-2009 Georgy Yunaev.
//
//  See LICENSE and README.md for more info.

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
