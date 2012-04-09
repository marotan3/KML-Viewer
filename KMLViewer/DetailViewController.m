//
//  DetailViewController.m
//  KMLViewer
//
//  Created by NextBusinessSystem on 11/12/01.
//  Copyright (c) 2011 NextBusinessSystem Co., Ltd. All rights reserved.
//

#import "DetailViewController.h"
#import "KMLAbstractGeometry+MapKit.h"
#import "MKShape+KML.h"

@implementation DetailViewController

@synthesize geometry = __geometry;
@synthesize webView = __webView;


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedString(@"Detail", nil);
    
    KMLPlacemark *placemark = self.geometry.placemark;
    
    NSString *htmlString = [NSString stringWithFormat:
                            @"<!DOCTYPE HTML>"
                            "<html>"
                            "<head>"
                            "<meta charset=\"UTF-8\">"
                            "<meta name=\"viewport\" content=\"initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no\">"
                            "<style type=\"text/css\">"
                            "body { margin: 0; background: white; color: black; font-family: arial,sans-serif; font-size: 13px;}"
                            "div { margin: 0; padding: 0; }"
                            "div[align=left] { text-align: -webkit-left; }"
                            "div#content { padding: 8px; }"
                            "div#name { font-weight: bold; padding-bottom: .7em; }"
                            "div#description { padding-bottom: .7em; }"
                            "</style>"
                            "</head>"
                            "<body>"
                            "<div id=\"content\">"
                            "<div>"
                            "<div align=\"left\" id=\"name\">%@</div>"
                            "<div align=\"left\" id=\"description\">%@</div>"
                            "</div>"
                            "</div>"
                            "</body>"
                            "</html>"
                            , placemark.name ? placemark.name : @""
                            , placemark.descriptionValue ? placemark.descriptionValue : @""];
    
    [self.webView loadHTMLString:htmlString baseURL:nil];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked
        || navigationType == UIWebViewNavigationTypeFormSubmitted) {
        
        [[UIApplication sharedApplication] openURL:request.URL];
        
        return NO;
    }

    return YES;
}

@end
