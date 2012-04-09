//
//  MapViewController.h
//  KMLViewer
//
//  Created by NextBusinessSystem on 11/12/01.
//  Copyright (c) 2011 NextBusinessSystem Co., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface MapViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISearchBar *placeSearchBar;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) IBOutlet UITableView *listView;
@property (strong, nonatomic) IBOutlet UITableView *searchResultView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *mapTypeButton;
@property (strong, nonatomic) IBOutlet UISegmentedControl *mapTypeControl;
@property (weak, nonatomic) IBOutlet UIButton *flipButton;

- (IBAction)mapTypeChanged:(id)sender;
- (IBAction)flip:(id)sender;
- (IBAction)open:(id)sender;

@end
