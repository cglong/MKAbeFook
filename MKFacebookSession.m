//
//  MKFacebookSession.m
//  MKAbeFook
//
//  Created by Mike Kinney on 9/19/09.
//  Copyright 2009 Mike Kinney. All rights reserved.
//
/*
 Copyright (c) 2009, Mike Kinney
 All rights reserved.
 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 Neither the name of MKAbeFook nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "MKFacebookSession.h"
#import "MKFacebookRequest.h"
#import "NSXMLDocumentAdditions.h"
#import "NSXMLElementAdditions.h"

NSString *MKFacebookAccessTokenKey = @"MKFacebookAccessToken";

@implementation MKFacebookSession

@synthesize appID;
@synthesize accessToken;
@synthesize _uid;

SYNTHESIZE_SINGLETON_FOR_CLASS(MKFacebookSession);

- (id)init{
	self = [super init];
	if(self != nil)
	{
        _uid = nil;
	}
	return self;
}

//TODO: implement saving an expiration date
- (void)saveAccessToken:(NSString *)aToken{
    //We're assuming the token is valid when it's passed in. How else can it be verified?
    if (aToken != nil) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:aToken forKey:MKFacebookAccessTokenKey];
        self.accessToken = aToken;
        _validSession = YES;
    }else{
        self.accessToken = nil;
        _validSession = NO;
    }
}

- (BOOL)loadAccessToken
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *defaultsAccessToken = [defaults objectForKey:MKFacebookAccessTokenKey];
    if (defaultsAccessToken != nil) {
        self.accessToken = defaultsAccessToken;
        MKFacebookRequest *request = [[[MKFacebookRequest alloc] init] autorelease];
        NSXMLDocument *user = [request fetchFacebookData:[request generateFacebookURLForMethod:@"users.getLoggedInUser" parameters:nil]];
        if ([user validFacebookResponse] == YES) {
            if (_uid) {
                [_uid release];
                _uid = nil;
            }
            _uid = [[[user rootElement] stringValue] retain];
            return YES;
        }else{
            DLog(@"persistent login failed, here's why...");
			DLog(@"%@", [user description]);
			return NO;
        }
    }
    
    return NO;
}


//TODO: verify session by sending a request to Facebook using session information
- (BOOL)validAccessToken{
	return [self loadAccessToken];
}

- (void)destroyAccessToken{
	DLog(@"session was destroyed");
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:MKFacebookAccessTokenKey];
	self.accessToken = nil;
    if (_uid != nil) {
        [_uid release];
    }
    _uid = nil;
	_validSession = NO;
}


- (NSString *)uid
{
    //see if one has already been set
    if (_uid != nil) {
        return _uid;
    }
    //try to fetch and set the uid
    if ([self loadAccessToken]) {
        return _uid;
    }
    //unable to fetch the uid using the stored access token
    return nil;
}


- (void)dealoc{
    [appID release];
    [accessToken release];
    [_uid release];
	[super dealloc];
}

@end
