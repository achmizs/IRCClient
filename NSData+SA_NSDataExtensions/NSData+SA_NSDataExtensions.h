//
//  NSData+SA_NSDataExtensions.h
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

#import <Foundation/Foundation.h>

/** \category NSData+SA_NSDataExtensions
 *	@brief Adds several utility methods to NSData.
 */
@interface NSData (SA_NSDataExtensions)

//	NOTE on stripping nulls from the ends of byte arrays.
//
//	If you strip a null from the end of an array which is something other than
//	a null-terminated C string (such as, for example, the bytes representing a
//	UTF-16 string), and thereby cause yourself difficulties, you have only
//	yourself to blame. Be sure that you know what your NSData objects are 
//	supposed to contain!

/**	Returns YES if the last byte of the stored data is null, NO otherwise.
 */
@property (readonly, getter=isNullTerminated) BOOL nullTerminated;

/** Returns the stored bytes as a null-terminated C string (byte array).
	
	If the stored data is already null-terminated, the returned pointer will
	be a pointer to the bytes managed by the receiver. If it is not already
	null-terminated, the returned pointer will point to bytes managed by a 
	copy of the receiver (and the bytes of the copy will be null-terminated).
 */
@property (readonly) const char *SA_terminatedCString;

/**	Returns data containing the stored bytes as a null-terminated C string
	(byte array).
	
	If the stored data is already null-terminated, this method simply returns
	the receiver. If it is not already null-terminated, this method returns a 
	reference to a fresh copy of the receiver (a copy that contains a 
	null-terminated byte array, of course).
 */
@property (readonly) NSData *SA_dataWithTerminatedCString;

/**	Returns the stored bytes as an non-null-terminated byte array.
 
	If the stored data was not null-terminated to begin with, the returned 
	pointer will be a pointer to the bytes managed by the receiver. If the 
	stored data was null-terminated, the returned pointer will point to bytes
	managed by a copy of the receiver (and the bytes of the copy will not be 
	null-terminated; but see NOTE).
 
	NOTE: If the receiver's *last* byte is null, the bytes pointed to by the
	returned pointer will have that null stripped; but if there are any more
	null bytes prior to that last null, they will remain untouched!
 */
@property (readonly) const char *SA_unterminatedByteString;

/**	Returns data containing the stored bytes as a non-null-terminated byte 
	array.
 
	If the stored data was not null-terminated to begin with, this method simply
	returns the receiver. If the stored data was null-terminated, this method 
	returns a reference to a fresh copy of the receiver (a copy that contains a
	non-null-terminated byte array, of course; but see NOTE).
 
	NOTE: If the receiver's *last* byte is null, the bytes managed by the
	returned object will have that null stripped; but if there are any more
	null bytes prior to that last null, they will remain untouched!
 */
@property (readonly) NSData *SA_dataWithUnterminatedByteString;

@end
