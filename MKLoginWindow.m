//
//  LoginWindow.m
//  MKAbeFook
//
//  Created by Mike on 10/11/06.
/*
 Copyright (c) 2009, Mike Kinney
 All rights reserved.
 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 Neither the name of MKAbeFook nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "MKLoginWindow.h"
#import "MKFacebookRequest.h"
#import "NSXMLElementAdditions.h"
#import "MKFacebookSession.h"
#import "NSStringExtras.h"

NSString *MKLoginRedirectURI = @"https://www.facebook.com/connect/login_success.html";

@interface MKLoginWindow (Private)

-(void)displayLoadingWindowIndicator;
-(void)hideLoadingWindowIndicator;
-(void)setWindowSize:(NSSize)windowSize;
-(void)windowWillClose:(NSNotification *)aNotification;

@end


@implementation MKLoginWindow
@synthesize _loginWindowIsSheet;
@synthesize _delegate;
@synthesize runModally;

-(id)init
{
	self = [super init];
	self._loginWindowIsSheet = NO;
	self._delegate = nil;
	self.runModally = NO;
	path = [[NSBundle bundleForClass:[self class]] pathForResource:@"LoginWindow" ofType:@"nib"];
	[super initWithWindowNibPath:path owner:self];
	return self;
}


-(void)awakeFromNib
{	
	[loginWebView setPolicyDelegate:self];
	[loadingWebViewProgressIndicator bind:@"value" toObject:loginWebView withKeyPath:@"estimatedProgress" options:nil];
	[self displayLoadingWindowIndicator];
}



-(void)loadURL:(NSURL *)loginURL
{
	[loginWebView setMaintainsBackForwardList:NO];
	[loginWebView setFrameLoadDelegate:self];
	
	DLog(@"loading url: %@", [loginURL description]);
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:loginURL];
	[[loginWebView mainFrame] loadRequest:request];
}


-(IBAction)closeWindow:(id)sender 
{
	if(self._loginWindowIsSheet == YES)
	{
		[[self window] orderOut:sender];
		[NSApp endSheet:[self window] returnCode:1];
		[self windowWillClose:nil];		
	}else
	{
		[[self window] performClose:sender];
	}
}


-(void)dealloc
{
	DLog(@"releasing login window");
	[_delegate release];
	[loginWebView stopLoading:nil];
	[loadingWebViewProgressIndicator unbind:@"value"];
	[super dealloc];
}



#pragma mark WebView Delegate Methods
- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
	[loadingWebViewProgressIndicator setHidden:NO];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame{
    [self hideLoadingWindowIndicator];    
}

-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [loadingWebViewProgressIndicator setHidden:YES];
	NSURL *url = [[[frame dataSource] mainResource] URL];
	NSString *urlString = [url description];
	DLog(@"current URL: %@", urlString);
	
    //if we find ourselves at the URL specified by the redirect_uri parameter we know the user pressed the login button or cancel button. we don't know if the login was successful yet.
	if([urlString hasPrefix:MKLoginRedirectURI])
	{
        //we can verify a successful login by identifying an #access_token in the URL. lets check for it.
        NSString *accessToken = [urlString substringBetweenString:@"#access_token=" andString:@"&"];
		if(accessToken != nil)
		{
            //we have identified an access token
            DLog(@"found access_token: %@", accessToken);
            
            //save it to the preferences
            [[MKFacebookSession sharedMKFacebookSession] saveAccessToken:accessToken];
            
            //display a custom successful login message that doesn't require an external host. if the application has the file FacebookLoginSuccess.html in its resources folder use that, otherwise we'll use the ugly one provided by the framework.
            NSString *next = [[NSBundle mainBundle] pathForResource:@"FacebookLoginSuccess" ofType:@"html"];
            if (! next)
            {
                NSString *fwp = [[NSBundle mainBundle] privateFrameworksPath];
                next = [NSString stringWithFormat:@"%@/MKAbeFook.framework/Resources/login_successful.html", fwp];
            }
            [self loadURL:[NSURL fileURLWithPath:[next stringByExpandingTildeInPath]]];
            
            //finally call userLoginSuccessful
            if([self._delegate respondsToSelector:@selector(userLoginSuccessful)])
                [self._delegate performSelector:@selector(userLoginSuccessful)];
            
            //we're done in this method
            return;
		}
        
        
        //TODO: move the error checking to be the first thing that happens. we don't want to display the login_success.html page that says 'Success' if the user clicked cancel even if it's only for a moment.
        //by the time we get here we know that the login wasn't successful, lets try to figure out what went wrong and what to do about it
        NSString *error_reason = [urlString substringBetweenString:@"error_reason=" andString:@"&"];
        //if the error_reason is user_denied, there is a good chance the user pressed the Cancel button in the login form. dismiss the window.
        if(error_reason != nil){
            //lets also hide the webview so the user doesn't see misleading messages
            [loginWebView setHidden:YES];
            if ([error_reason isEqualToString:@"user_denied"]) {
                [self closeWindow:self];   
            }
        }
        
    }
	
}

//allow external links to open in the default browser
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener
{
	if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue] != WebNavigationTypeOther) {
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
	else
		[listener use];
}

#pragma -


#pragma mark Private

-(void)displayLoadingWindowIndicator
{
	[loadingWindowProgressIndicator setHidden:NO];
	[loadingWindowProgressIndicator startAnimation:nil];
}

-(void)hideLoadingWindowIndicator
{
	[loadingWindowProgressIndicator stopAnimation:nil];
	[loadingWindowProgressIndicator setHidden:YES];
}

-(void)setWindowSize:(NSSize)windowSize
{
	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect rect = NSMakeRect(screenRect.size.width * .15, screenRect.size.height * .15, windowSize.width, windowSize.height);
	[[self window] setFrame:rect display:YES animate:YES];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	DLog(@"windowWillClose: was called");
    
	if (self.runModally == YES) {
		[NSApp stopModal];
	}else if (self._loginWindowIsSheet == YES)
	{
		[[self window] orderOut:[aNotification object]];
		[NSApp endSheet:[self window] returnCode:1];
	}
    
	//this is not the proper way to do this, someone please fix it.
	[self autorelease];
}
@end
