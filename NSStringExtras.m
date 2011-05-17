//
//  NSStringExtras.m
//  MKAbeFook
//
//  Created by Mike Kinney on 9/20/09.
//  Copyright 2009 Mike Kinney. All rights reserved.
//

#import "NSStringExtras.h"



@implementation NSString(NSStringExtras)
/*
 Encode a string legally so it can be turned into an NSURL
 Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSString/Encode_a_string_leg.m>
 (See copyright notice at <http://cocoa.karelia.com>)
 */

/*"	Fix a URL-encoded string that may have some characters that makes NSURL barf.
 It basicaly re-encodes the string, but ignores escape characters + and %, and also #.
 "*/
- (NSString *) encodeURLLegally
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(
																			NULL, (CFStringRef) self, (CFStringRef) @"%+#", NULL,
																			CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	return result;
}


//based on example from: http://stackoverflow.com/questions/3058799/nsstring-simple-pattern-matching
- (NSString *)substringBetweenString:(NSString *)start andString:(NSString *)stop{
    
    if([start length] == 0 || [stop length] == 0){
        return nil;
    }
    
    NSRange startRange = [self rangeOfString:start];
    NSRange stopRange = [self rangeOfString:stop];
    if (startRange.location != NSNotFound && stopRange.location != NSNotFound) {
        NSRange foundRange;
        //the start of the found range is after the length of startRange
        foundRange.location = startRange.location + startRange.length;
        //the end of the found range is (stop loc - start loc) also omit the start length
        foundRange.length = (stopRange.location - startRange.location) - startRange.length;
        return [self substringWithRange:foundRange];
    }
    return nil;
}
@end
