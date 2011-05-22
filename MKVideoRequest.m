//
//  MKVideoRequest.m
//  MKAbeFook
//
//  Created by Mike Kinney on 3/5/10.
//  Copyright 2010 Mike Kinney. All rights reserved.
//

#import "MKVideoRequest.h"

NSString *MKVideoAPIServerURL = @"https://api-video.facebook.com/method/";

@implementation MKVideoRequest

+ (id)requestWithDelegate:(id)aDelegate{
	MKVideoRequest *videoUpload = [[[MKVideoRequest alloc] initWithDelegate:aDelegate selector:nil] autorelease];
	return videoUpload;
}


- (id)initWithDelegate:(id)aDelegate selector:(SEL)aSelector{
	self = [super initWithDelegate:aDelegate selector:aSelector];
    [requestURL release];
	requestURL = [[NSURL URLWithString:MKVideoAPIServerURL] retain];
	return self;
}


- (void)videoGetUploadLimits{
	self.method = @"video.getUploadLimits";
	[self sendRequest];
}


- (void)videoUpload:(NSData *)video title:(NSString *)title description:(NSString *)description{
	[self setUrlRequestType:MKFacebookRequestTypePOST];
	self.method=@"video.upload";
	NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
	[params setObject:video forKey:@"video"];
	[params setValue:title forKey:@"title"];
	[params setValue:description forKey:@"description"];
	[self setParameters:params];
	[self sendRequest];
	[params release];
}
@end
