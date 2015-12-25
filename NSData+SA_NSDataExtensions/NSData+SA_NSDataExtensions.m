//
//  NSData+SA_NSDataExtensions.m
//
//  Copyright (c) 2015 Said Achmiz.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.

#import "NSData+SA_NSDataExtensions.h"

@implementation NSData (SA_NSDataExtensions)

-(BOOL)isNullTerminated
{
	return (((char*) self.bytes)[self.length - 1] == '\0');
}

-(const char *)SA_terminatedCString
{
	return self.SA_dataWithTerminatedCString.bytes;
}

-(NSData *)SA_dataWithTerminatedCString
{
	if(self.length == 0)
	{
		return [NSData dataWithBytes:"\0" length:1];
	}
	else if(self.isNullTerminated)
	{
		return self;
	}
	else
	{
		char* terminated_string_buffer = malloc(self.length + 1);
		[self getBytes:terminated_string_buffer length:self.length];
		terminated_string_buffer[self.length] = '\0';
		
		return [NSData dataWithBytesNoCopy:terminated_string_buffer length:(self.length + 1) freeWhenDone:YES];
	}
}

-(const char *)SA_unterminatedByteString
{
	return self.SA_dataWithUnterminatedByteString.bytes;
}

-(NSData *)SA_dataWithUnterminatedByteString
{
	if(self.length == 0 || self.isNullTerminated == NO)
	{
		return self;
	}
	else
	{
		char* unterminated_string_buffer = malloc(self.length - 1);
		[self getBytes:unterminated_string_buffer length:self.length - 1];
		
		return [NSData dataWithBytesNoCopy:unterminated_string_buffer length:(self.length - 1) freeWhenDone:YES];
	}
}

+(NSData *)dataWithBlankCString
{
	return [NSData dataWithBytes:"\0" length:1];
}

@end
