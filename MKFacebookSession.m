//
//  MKFacebookSession.m
//  MKAbeFook
//
//  Created by Mike Kinney on 9/19/09.
//  Copyright 2009 UNDRF. All rights reserved.
//

#import "MKFacebookSession.h"

NSString *MKFacebookSessionKey = @"MKFacebookSession";

@implementation MKFacebookSession

@synthesize session;

SYNTHESIZE_SINGLETON_FOR_CLASS(MKFacebookSession);

- (id)init{
	self = [super init];
	if(self != nil)
	{
		session = nil;
	}
	return self;
}

- (void)saveSession:(NSDictionary *)aSession{
	//TODO: check for a valid session before saving
	
	if(aSession != nil)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:aSession forKey:MKFacebookSessionKey];
		self.session = aSession;
	}
}

- (BOOL)loadSession{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *savedSession = [defaults objectForKey:MKFacebookSessionKey];
	//TODO: check for valid session before returning yes
	if(savedSession != nil)
	{
		self.session = savedSession;
		return YES;
	}else {
		self.session = nil;
		return NO;
	}
}

- (void)destroySession{
	self.session = nil;
}

- (NSString *)sessionKey{
	return [self.session valueForKey:@"session_key"];
}

- (NSString *)secret{
	return [self.session valueForKey:@"secret"];
}

- (NSString *)expirationDate{
	return [self.session valueForKey:@"expires"];
}

- (NSString *)uid{
	return [self.session valueForKey:@"uid"];
}

- (NSString *)sig{
	return [self.session valueForKey:@"sig"];
}


@end
