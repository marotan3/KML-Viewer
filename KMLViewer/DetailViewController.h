//
//  DetailViewController.h
//  KMLViewer
//
//  Created by NextBusinessSystem on 11/12/01.
//  Copyright (c) 2011 NextBusinessSystem Co., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <KML/KMLAbstractGeometry.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) KMLAbstractGeometry *geometry;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end
