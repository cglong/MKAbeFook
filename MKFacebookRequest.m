// 
//  MKFacebookRequest.m
//  MKAbeFook
//
//  Created by Mike on 12/15/07.
/*
 Copyright (c) 2009, Mike Kinney
 All rights reserved.
 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 Neither the name of MKAbeFook nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "MKFacebookRequest.h"
#import "NSStringExtras.h"
#import "NSXMLDocumentAdditions.h"
#import "NSXMLElementAdditions.h"
#import "MKErrorWindow.h"
#import "CocoaCryptoHashing.h"
#import "JSON.h"
#import "NSDictionaryAdditions.h"


NSString *MKFacebookRequestActivityStarted = @"MKFacebookRequestActivityStarted";
NSString *MKFacebookRequestActivityEnded = @"MKFacebookRequestActivityEnded";

@interface MKFacebookRequest (Private)
- (NSString *)generateFacebookMethodURL;
@end


@implementation MKFacebookRequest

@synthesize connectionTimeoutInterval;
@synthesize method;
@synthesize responseFormat;
@synthesize rawResponse;

#pragma mark init methods
+ (id)requestWithDelegate:(id)aDelegate
{
	MKFacebookRequest *theRequest = [[[MKFacebookRequest alloc] initWithDelegate:aDelegate selector:nil] autorelease];
	return theRequest;	
}


+ (id)requestWithDelegate:(id)aDelegate selector:(SEL)aSelector
{
	MKFacebookRequest *theRequest = [[[MKFacebookRequest alloc] initWithDelegate:aDelegate selector:aSelector] autorelease];
	return theRequest;
}


- (id)init
{
	self = [super init];
	if(self != nil)
	{
		_delegate = nil;
		_selector = nil;
		
		_responseData = [[NSMutableData alloc] init];
		_parameters = [[NSMutableDictionary alloc] init];
		_urlRequestType = MKFacebookRequestTypePOST;
		responseFormat = MKFacebookRequestResponseFormatXML;
		requestURL = [[NSURL URLWithString:MKAPIServerURL] retain];
		_displayAPIErrorAlert = NO;
		_numberOfRequestAttempts = 5;
		_session = [MKFacebookSession sharedMKFacebookSession];
		self.connectionTimeoutInterval = 30;
		self.method = nil;
		rawResponse = nil;
		
		defaultResponseSelector = @selector(facebookRequest:responseReceived:);
		defaultErrorSelector = @selector(facebookRequest:errorReceived:);
		defaultFailedSelector = @selector(facebookRequest:failed:);
		
		deprecatedResponseSelector = @selector(facebookResponseReceived:);
		deprecatedErrorSelector = @selector(facebookErrorResponseReceived:);
		deprecatedFailedSelector = @selector(facebookRequestFailed:);
		
	}
	return self;
}


- (id)initWithDelegate:(id)aDelegate selector:(SEL)aSelector
{

	self = [self init];
	if(self != nil)
	{
		[self setDelegate:aDelegate];
		if(aSelector != nil)
			[self setSelector:aSelector];			
	}
	return self;
}


- (id)initWithParameters:(NSDictionary *)parameters delegate:(id)aDelegate selector:(SEL)aSelector{
	
	self = [self initWithDelegate:aDelegate selector:aSelector];
	if(self != nil)
	{
		
	}
	return self;
}


-(void)dealloc
{
	[requestURL release];
	[_parameters release];
	[_responseData release];
	[method release];
	[rawResponse release];
	[super dealloc];
}
#pragma mark -


#pragma mark Instance Methods
- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}


- (id)delegate
{
	return _delegate;
}


- (void)setSelector:(SEL)selector
{
	_selector = selector;
}


- (void)setParameters:(NSDictionary *)parameters
{
    //we don't want the method variable in the parameters dictionary anymore, if we find it remove it
    if ([parameters objectForKey:@"method"]) {
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
        [params removeObjectForKey:@"method"];
        [_parameters addEntriesFromDictionary:params];
    }else{
        [_parameters addEntriesFromDictionary:parameters];
    }
	
}


- (void)setURLRequestType:(MKFacebookRequestType)urlRequestType
{
	_urlRequestType = urlRequestType;
}


- (MKFacebookRequestType)urlRequestType
{
	return _urlRequestType;
}


-(void)setRequestFormat:(MKFacebookRequestResponseFormat)requestFormat
{
	responseFormat = requestFormat;
}


- (void)sendRequestWithParameters:(NSDictionary *)parameters
{
    [self setParameters:parameters];
    [self sendRequest];
}


- (void)sendRequest:(NSString *)aMethod withParameters:(NSDictionary *)parameters
{
	self.method = aMethod;
	[self setParameters:parameters];
	[self sendRequest];
}


- (void)sendRequest
{	
    NSAssert(self.method != nil, @"Request method not set");
    
    //a valid access token is required for all requests
    //TODO: error out request if toke is not found
	NSString *accessToken = [[MKFacebookSession sharedMKFacebookSession] accessToken];
    if (accessToken != nil) {
        [_parameters setValue:accessToken forKey:@"access_token"];
    }

		
	NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSString *applicationVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *userAgent;
	if(applicationName != nil && applicationVersion != nil)
		userAgent = [NSString stringWithFormat:@"%@ %@", applicationName, applicationVersion];
	else
		userAgent = @"MKAbeFook";
	
	
	_requestIsDone = NO;
	if(_urlRequestType == MKFacebookRequestTypePOST)
	{
		//NSLog([_facebookConnection description]);
        NSURL *url = [NSURL URLWithString:[self generateFacebookMethodURL]];
		NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:url 
																	 cachePolicy:NSURLRequestReloadIgnoringCacheData 
																 timeoutInterval:[self connectionTimeoutInterval]];
		
		[postRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
		
		NSMutableData *postBody = [NSMutableData data];
		NSString *stringBoundary = [NSString stringWithString:@"xXxiFyOuTyPeThIsThEwOrLdWiLlExPlOdExXx"];
		NSData *endLineData = [[NSString stringWithFormat:@"\r\n--%@\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding];
		NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", stringBoundary];
		[postRequest setHTTPMethod:@"POST"];
		[postRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
		[postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];

		switch (self.responseFormat) {
			case MKFacebookRequestResponseFormatXML:
				[_parameters setValue:@"XML" forKey:@"format"];
				break;
			case MKFacebookRequestResponseFormatJSON:
				[_parameters setValue:@"JSON" forKey:@"format"];
				break;
			default:
				[_parameters setValue:@"XML" forKey:@"format"];
				break;
		}
		
		
		
		
		//if parameters contains a NSImage or NSData object we need store the key so it can be removed from the _parameters dictionary before a signature is generated for the request
		NSString *imageKey = nil;
		NSString *dataKey = nil;
		
		for(id key in [_parameters allKeys])
		{
			
			if([[_parameters objectForKey:key] isKindOfClass:[NSImage class]])
			{
				NSData *resizedTIFFData = [[_parameters objectForKey:key] TIFFRepresentation];
				NSBitmapImageRep *resizedImageRep = [NSBitmapImageRep imageRepWithData: resizedTIFFData];
				NSDictionary *imageProperties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat: 1.0] forKey:NSImageCompressionFactor];
				NSData *imageData = [resizedImageRep representationUsingType: NSJPEGFileType properties: imageProperties];
				
				[postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; filename=\"image\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:[[NSString stringWithString:@"Content-Type: image/jpeg\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];	
				[postBody appendData: imageData];
				[postBody appendData:endLineData];
				
				//we need to remove this the image object from the dictionary so we can generate a correct sig from the other values, but we can't do it here or leopard will complain.  so we'll do it outside the loop.
				//[_parameters removeObjectForKey:key];
				imageKey = [NSString stringWithString:key];

			}
			else if( [[_parameters objectForKey:key] isKindOfClass:[NSData class]] ){
				[postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; filename=\"data.mov\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:[[NSString stringWithString:@"Content-Type: content/unknown\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];	
				[postBody appendData:(NSData *)[_parameters objectForKey:key]];
				[postBody appendData:endLineData];
				dataKey = [NSString stringWithString:key];
				
			}
			else if ([[_parameters objectForKey:key] isKindOfClass:[NSArray class]])
			{
				NSString *stringFromArray = [[_parameters objectForKey:key] componentsJoinedByString:@","];
				[postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:[stringFromArray dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:endLineData];
			}
			else
			{
			 
				[postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:[[_parameters valueForKey:key] dataUsingEncoding:NSUTF8StringEncoding]];
				[postBody appendData:endLineData];
			}
			 
		}
		//0.7.1 fix.  we can't remove this during the while loop so we'll do it here
		if(imageKey != nil)
			[_parameters removeObjectForKey:imageKey];
		
		if (dataKey != nil)
			[_parameters removeObjectForKey:dataKey];
					
		[postBody appendData:endLineData];
		
		[postRequest setHTTPBody:postBody];
		theConnection = [NSURLConnection connectionWithRequest:postRequest delegate:self];
	}
	
	if(_urlRequestType == MKFacebookRequestTypeGET)
	{
		DLog(@"using get request");
		NSURL *theURL = [self generateFacebookURLForMethod:self.method parameters:_parameters];
		
		NSMutableURLRequest *getRequest = [NSMutableURLRequest requestWithURL:theURL 
																  cachePolicy:NSURLRequestReloadIgnoringCacheData 
															  timeoutInterval:[self connectionTimeoutInterval]];
		[getRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
		
		theConnection = [NSURLConnection connectionWithRequest:getRequest delegate:self];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"MKFacebookRequestActivityStarted" object:nil];
	 
}


- (void)cancelRequest
{
	if(_requestIsDone == NO)
	{
		//NSLog(@"cancelling request...");
		[theConnection cancel];
		_requestIsDone = YES;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MKFacebookRequestActivityEnded" object:nil];
}


- (void)setDisplayAPIErrorAlert:(BOOL)aBool
{
	_displayAPIErrorAlert = aBool;
}


- (BOOL)displayAPIErrorAlert
{
	return _displayAPIErrorAlert;
}


- (void)setNumberOfRequestAttempts:(int)requestAttempts
{
	_numberOfRequestAttempts = requestAttempts;
}


//this private method prepares the url to call the appropriate method but does not add any of the required parameters. it is used to prepare the first part of the URL.
/*
 i.e. if a method users.getInfo is specified for the request, this method will prepare the url up to this point:
 https://api.facebook.com/method/users.getInfo
 
 All other parameters required by the request are handled in sendRequest where it loops through the _parameters dictionary to finish preparing the request
 */
- (NSString *)generateFacebookMethodURL{
    NSMutableString *urlString = [NSMutableString stringWithString:MKAPIServerURL];
    NSAssert(self.method != nil, @"Method name cannot be null");
    [urlString appendFormat:@"%@", self.method];
    return urlString;
}


- (NSURL *)generateFacebookURLForMethod:(NSString *)aMethodName parameters:(NSDictionary *)parameters
{
    
    self.method = aMethodName;
    [self setParameters:parameters];
    
	NSString *accessToken = [[MKFacebookSession sharedMKFacebookSession] accessToken];
    
    NSMutableString *urlString = [NSMutableString stringWithString:[self generateFacebookMethodURL]];
    
    //add the accessToken that all requests need
    [urlString appendFormat:@"?access_token=%@", accessToken];
    
    //support arrays or strings
    for(NSString *key in [_parameters allKeys]){
        id object = [_parameters objectForKey:key];
        if ([object isKindOfClass:[NSArray class]]) {
            [urlString appendFormat:@"&%@=%@", key, [object componentsJoinedByString:@","]];
        }
        if([object isKindOfClass:[NSString class]]){
            [urlString appendFormat:@"&%@=%@", key, object];
        }
    }
    DLog(@"generateFacebookURLForMethod: %@", urlString);
	return [NSURL URLWithString:[[urlString encodeURLLegally] autorelease]];
}


- (id)fetchFacebookData:(NSURL *)theURL
{
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:theURL 
												cachePolicy:NSURLRequestReloadIgnoringCacheData
											timeoutInterval:[self connectionTimeoutInterval]];
	NSHTTPURLResponse *xmlResponse;  //not used right now
	NSXMLDocument *returnXML = nil;
	NSError *fetchError = nil;
	NSData *responseData = [NSURLConnection sendSynchronousRequest:urlRequest
												 returningResponse:&xmlResponse
															 error:&fetchError];
	
	if(fetchError != nil)
	{
		if(_displayAPIErrorAlert == YES)
		{
			MKErrorWindow *errorWindow = [MKErrorWindow errorWindowWithTitle:@"Network Problems?" message:@"I can't seem to talk to Facebook.com right now." details:[fetchError description]];
			[errorWindow display];
			DLog(@"synchronous fetch error %@", [fetchError description]);
		}
		
		return nil;
	}else
	{
		returnXML = [[[NSXMLDocument alloc] initWithData:responseData
												 options:0
												   error:nil] autorelease];
	}
	
	return returnXML;
	
	
}
#pragma mark -


#pragma mark NSURLConnection Delegate Methods
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_responseData appendData:data];
}

//responses are ONLY passed back if they do not contain any errors
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MKFacebookRequestActivityEnded" object:nil];
	
	
	NSError *error = nil;
	//assume the response is not valid until we can verify it is good
	BOOL validResponse = NO;

	
	//turn the response into a string so we can parse it if it's JSON or turn it into NSXML if we're expecting XML
	NSString *responseString = [[[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding] autorelease];

	
	if (responseString != nil && [responseString length] > 0) {
		validResponse = YES;
		rawResponse = [responseString copy];
	}else {
		rawResponse = nil;
	}


	
	if (self.responseFormat == MKFacebookRequestResponseFormatXML && validResponse == YES) {
		
		NSXMLDocument *returnXML = [[[NSXMLDocument alloc] initWithXMLString:responseString options:0 error:&error] autorelease];
		
		if (error != nil) {
			validResponse = NO;
		}
		
		
		//facebook has returned an error of some kind. evaluate the error and try resending the request if possible
		if([returnXML validFacebookResponse] == NO)
		{
			NSDictionary *errorDictionary = [[returnXML rootElement] dictionaryFromXMLElement];
			//4 is a magic number that represents "The application has reached the maximum number of requests allowed. More requests are allowed once the time window has completed."
			//luckily for us Facebook doesn't define "the time window".
			//we will also try the request again if we see a 1 (unknown) or 2 (service unavailable) error
			int errorInt = [[errorDictionary valueForKey:@"error_code"] intValue];
			if((errorInt == 4 || errorInt == 1 || errorInt == 2 ) && _numberOfRequestAttempts <= _requestAttemptCount)
			{
				NSDate *sleepUntilDate = [[NSDate date] addTimeInterval:2.0];
				[NSThread sleepUntilDate:sleepUntilDate];
				[_responseData setData:[NSData data]];
				_requestAttemptCount++;
				DLog(@"Too many requests, waiting just a moment....%@", [self description]);
				[self sendRequest];
				return;
			}
			//DLog(@"I give up, the request has been attempted %i times but it just won't work. Here is the failed request: %@", _requestAttemptCount, [_parameters description]);
			//we've tried the request a few times, now we're giving up.
			validResponse = NO;
		}else
		{
			//the response we have received from facebook is valid, pass it back to the delegate.
			if([_delegate respondsToSelector:_selector]){
				[_delegate performSelector:_selector withObject:returnXML];
			}else if ([_delegate respondsToSelector:defaultResponseSelector]) {
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_delegate methodSignatureForSelector:defaultResponseSelector]];
				[invocation setTarget:_delegate];
				[invocation setSelector:defaultResponseSelector];
				[invocation setArgument:&self atIndex:2];
				[invocation setArgument:&returnXML atIndex:3];
				[invocation invoke];
			}else if ([_delegate respondsToSelector:deprecatedResponseSelector]) {
				[_delegate performSelector:deprecatedResponseSelector withObject:returnXML];
			}
		}	
		
	}
	
	

	
	
	if (self.responseFormat == MKFacebookRequestResponseFormatJSON && validResponse == YES) {
		id returnJSON = [responseString JSONValue];

		if ([returnJSON isKindOfClass:[NSDictionary class]] || [returnJSON isKindOfClass:[NSArray class]]) {

			//JSON returning a NSDictionary can be good or bad because errors are turned into dictionaries.
			if ([returnJSON isKindOfClass:[NSDictionary class]])
			{
				//DLog(@"JSON response parsed to dictionary");
				if ([returnJSON validFacebookResponse] == YES) {
					validResponse = YES;
				}else{
					//DLog(@"invalid facebook response received");
					validResponse = NO;
					//exactly like the XML part, check for error 4, 1, or 2 (defined above in the XML handling part)
					int errorInt = [[returnJSON valueForKey:@"error_code"] intValue];
					if((errorInt == 4 || errorInt == 1 || errorInt == 2 ) && _numberOfRequestAttempts <= _requestAttemptCount)
					{
						NSDate *sleepUntilDate = [[NSDate date] addTimeInterval:2.0];
						[NSThread sleepUntilDate:sleepUntilDate];
						[_responseData setData:[NSData data]];
						_requestAttemptCount++;
						DLog(@"Too many requests, waiting just a moment....%@", [self description]);
						[self sendRequest];
						return;
					}
					//DLog(@"I give up, the request has been attempted %i times but it just won't work. Here is the failed request: %@", _requestAttemptCount, [_parameters description]);

				} //end checking / handling a NSDictionary for a valid or failed response
				
			}else if ([returnJSON isKindOfClass:[NSArray class]]) {
				//if the JSON parses out to an array i think it can only mean it's valid...
				validResponse = YES;
			}
			
			//response appears to be valid, return it to the delegate either via a specified selector or the default selector
			if (validResponse == YES) {
				//DLog(@"JSON looks good, trying to pass back to the delegate");
				if ([_delegate respondsToSelector:_selector]) {
					[_delegate performSelector:_selector withObject:returnJSON];
				}else if ([_delegate respondsToSelector:defaultResponseSelector]) {
					NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_delegate methodSignatureForSelector:defaultResponseSelector]];
					[invocation setTarget:_delegate];
					[invocation setSelector:defaultResponseSelector];
					[invocation setArgument:&self atIndex:2];
					[invocation setArgument:&returnJSON atIndex:3];
					[invocation invoke];
				}else if ([_delegate respondsToSelector:deprecatedResponseSelector]) {
					[_delegate performSelector:deprecatedResponseSelector withObject:returnJSON];
				}		
			}
			
			//DLog(@"returnJSON class: %@", [returnJSON className]);
			//DLog(@"parsed JSON: %@", [returnJSON description]);
		}
	}
	
	

	
	if (validResponse == NO) {
		
		MKFacebookResponseError *responseError = [MKFacebookResponseError errorFromRequest:self];
		DLog(@"Facebook Error Code: %lu", (unsigned long)responseError.errorCode);
		DLog(@"Facebook Error Message: %@", responseError.errorMessage);
		DLog(@"Facebook Error Arguments: %@", [responseError.requestArgs description]);
		
		if ([self displayAPIErrorAlert] == YES) {
			NSString *errorString = @"Unknown Error";
			
			if (self.rawResponse == nil) {
				errorString = [NSString stringWithString:@"Facebook did not return any data that could be interpreted as JSON or XML. Services may be unavailable."];				
			}else {
				errorString = [NSString stringWithString:@"Facebook returned an error."];
			}

			MKErrorWindow *errorWindow = [MKErrorWindow errorWindowWithTitle:@"API Error" 
																	 message:errorString 
																	 details:rawResponse];
			[errorWindow display];
		}

		
		//pass the error back to the delegate
		if([_delegate respondsToSelector:defaultErrorSelector])
		{
			
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_delegate methodSignatureForSelector:defaultErrorSelector]];
			[invocation setTarget:_delegate];
			[invocation setSelector:defaultErrorSelector];
			[invocation setArgument:&self atIndex:2];
			[invocation setArgument:&responseError atIndex:3];
			[invocation invoke];
		}else if ([_delegate respondsToSelector:deprecatedErrorSelector]) {
			[_delegate performSelector:deprecatedErrorSelector withObject:rawResponse];
		}
	}
		
	
	
	[_responseData setData:[NSData data]];
	_requestIsDone = YES;
	
}

//0.6 suggestion to pass connection error.  Thanks Adam.
-  (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{	
	
	if([self displayAPIErrorAlert])
	{
		MKErrorWindow *errorWindow = [MKErrorWindow errorWindowWithTitle:@"Connection Error" message:@"Are you connected to the internet?" details:[[error userInfo] description]];
		[errorWindow display];
	}
	
	if([_delegate respondsToSelector:defaultFailedSelector])
	{
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_delegate methodSignatureForSelector:defaultFailedSelector]];
		[invocation setTarget:_delegate];
		[invocation setSelector:defaultFailedSelector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&error atIndex:3];
		[invocation invoke];
	}else if ([_delegate respondsToSelector:deprecatedFailedSelector]) {
		[_delegate performSelector:deprecatedFailedSelector withObject:error];
	}
		
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MKFacebookRequestActivityEnded" object:self];
}


//only works in 10.6
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten 
											   totalBytesWritten:(NSInteger)totalBytesWritten 
									   totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
	SEL forwardSelector = @selector(facebookRequest:bytesWritten:totalBytesWritten:totalBytesExpectedToWrite:);
	if ([_delegate respondsToSelector:forwardSelector]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_delegate methodSignatureForSelector:forwardSelector]];
		[invocation setTarget:_delegate];
		[invocation setSelector:forwardSelector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&bytesWritten atIndex:3];
		[invocation setArgument:&totalBytesWritten atIndex:4];
		[invocation setArgument:&totalBytesExpectedToWrite atIndex:5];
		[invocation invoke];
	}
}

#pragma mark -


@end
