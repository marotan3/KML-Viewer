//
//  MapViewController.m
//  KMLViewer
//
//  Created by NextBusinessSystem on 11/12/01.
//  Copyright (c) 2011 NextBusinessSystem Co., Ltd. All rights reserved.
//

#import <MapKit/MapKit.h>
#import <zlib.h>
#import "KML.h"
#import "MapViewController.h"
#import "DetailViewController.h"
#import "KML+MapKit.h"
#import "MKMap+KML.h"
#import "ZipFile.h"
#import "ZipException.h"
#import "FileInZipInfo.h"
#import "ZipWriteStream.h"
#import "ZipReadStream.h"
#import "SVProgressHUD.h"

@interface MapViewController ()
@property (strong) IBOutlet UISearchBar *placeSearchBar;
@property (strong) IBOutlet UIView *contentView;
@property (strong) IBOutlet MKMapView *mapView;
@property (strong) IBOutlet UITableView *listView;
@property (strong) IBOutlet UITableView *searchResultView;
@property (strong) IBOutlet UIToolbar *toolBar;
@property (strong) IBOutlet UIBarButtonItem *mapTypeButton;
@property (strong) IBOutlet UISegmentedControl *mapTypeControl;
@property (strong) IBOutlet UIBarButtonItem *flipButton;
@property (strong) MKUserTrackingBarButtonItem *trackingButton;
@property (strong) UIBarButtonItem *openButton;

@property (nonatomic) KMLRoot *kml;
@property (nonatomic) NSArray *geometries;
@property (nonatomic) NSArray *filteredGeometries;
@end

@interface MapViewController (UIAlertViewDelegate) <UIAlertViewDelegate>
@end

@interface MapViewController (UISearchBarDelegate) <UISearchBarDelegate>
- (void)filterPlacemarkForSearchText:(NSString*)searchText;
@end

@interface MapViewController (MKMapViewDelegate) <MKMapViewDelegate>
- (void)loadMapType;
- (void)saveMapType;
- (void)reloadMapView;
@end

@interface MapViewController (UITableViewDataSource) <UITableViewDataSource>
@end

@interface MapViewController (UITableViewDelegate) <UITableViewDelegate>
- (void)tableViewWillAppear:(UITableView *)tableView;
@end



@implementation MapViewController

#pragma mark - Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"KMLViewerDidReceiveNewURL" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewURL:) name:@"KMLViewerDidReceiveNewURL" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultDidChangeNotification:) name:NSUserDefaultsDidChangeNotification object:nil];

    // initialize variables
    self.geometries = @[];
    self.filteredGeometries = @[];

    // setup segmented control
    self.title = NSLocalizedString(@"Map", nil);
    [self.mapTypeControl setTitle:NSLocalizedString(@"Standard", nil) forSegmentAtIndex:0];
    [self.mapTypeControl setTitle:NSLocalizedString(@"Satellite", nil) forSegmentAtIndex:1];
    [self.mapTypeControl setTitle:NSLocalizedString(@"Hybrid", nil) forSegmentAtIndex:2];

    // setup search bar
    UIView *barWrapper = [[UIView alloc]initWithFrame:self.placeSearchBar.bounds];
    [barWrapper addSubview:self.placeSearchBar];
    self.navigationItem.titleView = barWrapper;
    
    // setup the tracking button
    self.trackingButton = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    NSMutableArray *items = self.toolBar.items.mutableCopy;
    [items insertObject:self.trackingButton atIndex:0];
    self.toolBar.items = items;
    
    // setup the open button
    self.openButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Open", nil)
                                                       style:UIBarButtonItemStyleBordered 
                                                      target:self
                                                      action:@selector(open:)];
    
    [self loadMapType];

    // load last KML
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *urlString = [defaults objectForKey:@"url"];
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [self loadKMLAtURL:url];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self tableViewWillAppear:self.listView];

    if (!self.searchResultView.hidden) {
        [self.placeSearchBar becomeFirstResponder];
        [self tableViewWillAppear:self.searchResultView];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    // reset tracking mode
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Public methods

- (IBAction)mapTypeChanged:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    self.mapView.mapType = segmentedControl.selectedSegmentIndex;
    
    [self saveMapType];
}

- (IBAction)flip:(id)sender
{
    // reset tracking mode
    self.mapView.userTrackingMode = MKUserTrackingModeNone;
    
    // flip the content view
    [UIView transitionWithView:self.contentView
                      duration:0.5f
                       options:[self.mapView superview] ? UIViewAnimationOptionTransitionFlipFromLeft : UIViewAnimationOptionTransitionFlipFromRight
                    animations:^{
                        if ([self.mapView superview]) {
                            [self.mapView removeFromSuperview];
                            [self.contentView addSubview:self.listView];
                        } else {
                            [self.listView removeFromSuperview];
                            [self.contentView addSubview:self.mapView];
                        }
                    }
                    completion:^(BOOL finished) {
                        if (finished) {
                            // replace toolbar items
                            NSMutableArray *items = self.toolBar.items.mutableCopy;
                            if (![self.mapView superview]) {
                                [items removeObject:self.trackingButton];
                                [items removeObject:self.mapTypeButton];
                                [items insertObject:self.openButton atIndex:0];
                            } else {
                                [items removeObject:self.openButton];
                                [items insertObject:self.trackingButton atIndex:0];
                                [items insertObject:self.mapTypeButton atIndex:2];
                            }
                            self.toolBar.items = items;

                            // update flip button title
                            if (self.mapView.superview) {
                                [self.flipButton setTitle:NSLocalizedString(@"List", nil)];
                            } else {
                                [self.flipButton setTitle:NSLocalizedString(@"Map", nil)];
                            }
                        }
                    }
     ];
}

- (IBAction)open:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:NSLocalizedString(@"Open", nil)
                                                   message:NSLocalizedString(@"Enter the URL of KML file.", nil) 
                                                  delegate:self 
                                         cancelButtonTitle:NSLocalizedString(@"Cancel", nil) 
                                         otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL;
    [alert show];
}


#pragma mark - Private method

- (NSString *)inboxDirectory
{
    NSArray *pathList = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = pathList[0];
    return [documentsDirectory stringByAppendingPathComponent:@"Inbox"];
}

- (void)loadKMLAtURL:(NSURL *)url
{
    [SVProgressHUD show];
    self.navigationController.view.userInteractionEnabled = NO;

    // remove all annotations and overlays
    NSMutableArray *annotations = @[].mutableCopy;
    [self.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        if (![obj isKindOfClass:[MKUserLocation class]]) {
            [annotations addObject:obj];
        }
    }];
    [self.mapView removeAnnotations:annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    
    // load new KML
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // observe KML format error
        [[NSNotificationCenter defaultCenter] addObserverForName:kKMLInvalidKMLFormatNotification 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note){
                                                          NSString *description = [[note userInfo] valueForKey:kKMLDescriptionKey];
                                                          DLog(@"%@", description);
                                                      }
         ];
        
        if ([[[url absoluteString] pathExtension] isEqualToString:@"kmz"]) {
            // inflate zip
            NSString *fileName = [[url absoluteString] lastPathComponent];
            NSString *filePath = nil;
            
            if ([[url absoluteString] hasPrefix:@"file://"]) {
                // kmz already saved at Inbox
                filePath = [[self inboxDirectory] stringByAppendingPathComponent:fileName];

            } else {
                // need download kmz to temprary
                filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                NSError *downloadError;
                NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&downloadError];
                if (downloadError) {
                    DLog(@"error, %@", downloadError);
                } else {
                    [data writeToFile:filePath atomically:YES];
                }
            }
            
            if (filePath) {
                __block NSMutableData *data;
                ZipFile *kmzFile;
                @try {
                    kmzFile = [[ZipFile alloc] initWithFileName:filePath mode:ZipFileModeUnzip];

                    [kmzFile.listFileInZipInfos enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
                    {
                        FileInZipInfo *info = (FileInZipInfo *)obj;
                        
                        NSString *ext = info.name.pathExtension.lowercaseString;
                        
                        if ([ext isEqualToString:@"kml"]) {
                            [kmzFile locateFileInZip:info.name];
                            
                            ZipReadStream *reader= kmzFile.readCurrentFileInZip;
                            data = [[NSMutableData alloc] initWithLength:info.length];
                            [reader readDataWithBuffer:data];
                            [reader finishedReading];
                            
                            *stop = YES;
                        }
                    }];
                }
                @catch (NSException *exception) {
                    DLog(@"exception, %@", [exception debugDescription]);
                }
                @finally {
                    if (kmzFile) {
                        [kmzFile close];
                    }
                }

                if (data) {
                    self.kml = [KMLParser parseKMLWithData:data];
                }
            }

        } else {
            self.kml = [KMLParser parseKMLAtURL:url];
        }
        
        // remove KML format error observer
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kKMLInvalidKMLFormatNotification object:nil];
        
        if (self.kml) {
            // save curent url for next load
            NSString *urlString = [url absoluteString];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:urlString forKey:@"url"];
            [defaults synchronize];

            self.geometries = self.kml.geometries;

            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                self.navigationController.view.userInteractionEnabled = YES;

                [self reloadMapView];
                [self.listView reloadData];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                self.navigationController.view.userInteractionEnabled = YES;
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                    message:NSLocalizedString(@"Failed to read the KML file", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                          otherButtonTitles:nil];
                [alertView show];
            });
        }
    });
}

- (void)didReceiveNewURL:(NSNotification *)notification
{
    NSURL *url = (NSURL *)notification.object;
    
    [self loadKMLAtURL:url];
}

- (void)userDefaultDidChangeNotification:(NSNotification *)notification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL clearHistory = [defaults boolForKey:@"clear_history"];
    
    if (clearHistory) {
        // delete cache files
        NSString *inboxDirectory = [self inboxDirectory];
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inboxDirectory error:nil];
        [files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            NSString *path = (NSString *)obj;
            NSString *fullPath = [inboxDirectory stringByAppendingPathComponent:path];
            DLog(@"delete, %@", fullPath);
            [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
        }];
        
        // remove all annotations and overlays
        NSMutableArray *annotations = @[].mutableCopy;
        [self.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            id<MKAnnotation> annotation = (id<MKAnnotation>)obj;

            if (![annotation isKindOfClass:[MKUserLocation class]]) {
                [annotations addObject:annotation];
            }
        }];
        [self.mapView removeAnnotations:annotations];
        [self.mapView removeOverlays:self.mapView.overlays];

        self.kml = nil;
        self.geometries = @[];
        self.filteredGeometries = @[];
        
        [self.listView reloadData];
        [self.searchResultView reloadData];

        // reset settings
        [defaults setBool:NO forKey:@"clear_history"];
        [defaults setObject:nil forKey:@"url"];
        [defaults synchronize];
    }
}

- (void)pushDetailViewControllerWithGeometry:(KMLAbstractGeometry *)geometry
{
    DetailViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"DetailViewController"];
    if (viewController) {
        viewController.geometry = geometry;
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end


#pragma mark - 
@implementation MapViewController (UIAlertViewDelegate)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex) {
        NSString *urlString = [alertView textFieldAtIndex:0].text;
        
        if (!urlString || urlString.length == 0) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                message:NSLocalizedString(@"Please enter the URL", nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
            return;
        }
        
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                message:NSLocalizedString(@"Failed to open the URL", nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
            return;
        }
        
        [self loadKMLAtURL:url];
    }
}

@end


#pragma mark - 
@implementation MapViewController (UISearchBarDelegate)

- (void)filterPlacemarkForSearchText:(NSString*)searchText
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"placemark.name contains[c] %@", searchText];
    self.filteredGeometries = [self.geometries filteredArrayUsingPredicate:predicate];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
    
    // show table view
    if (self.searchResultView.hidden) {
        self.searchResultView.hidden = NO;
        [UIView animateWithDuration:0.5f
                         animations:^{
                             self.searchResultView.alpha = 1.f;
                         }
         ];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    
    [searchBar setShowsCancelButton:NO animated:YES];
    
    self.filteredGeometries = @[];
    
    [self.searchResultView reloadData];
    
    // hide table view
    if (!self.searchResultView.hidden) {
        self.searchResultView.hidden = NO;
        [UIView animateWithDuration:0.5f
                         animations:^{
                             self.searchResultView.alpha = 0.f;
                         }
                         completion:^(BOOL finished) {
                             if (finished) {
                                 self.searchResultView.hidden = YES;
                             }
                         }
         ];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self filterPlacemarkForSearchText:searchText];
    [self.searchResultView reloadData];
}

@end


#pragma mark - 
@implementation MapViewController (MKMapViewDelegate)

- (void)loadMapType
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *mapType = [defaults objectForKey:@"map-type"];
    if (!mapType) {
        mapType = @(0);
    }
    
    self.mapView.mapType = [mapType integerValue];
    self.mapTypeControl.selectedSegmentIndex = [mapType integerValue];
}

- (void)saveMapType
{
    NSNumber *mapType = @(self.mapView.mapType);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mapType forKey:@"map-type"];
    [defaults synchronize];
}

- (void)reloadMapView
{
    NSMutableArray *annotations = @[].mutableCopy;
    NSMutableArray *overlays = @[].mutableCopy;
    
    [self.geometries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
    {
        KMLAbstractGeometry *geometry = (KMLAbstractGeometry *)obj;
        MKShape *mkShape = [geometry mapkitShape];
        if (mkShape) {
            if ([mkShape conformsToProtocol:@protocol(MKOverlay)]) {
                [overlays addObject:mkShape];
            }
            else if ([mkShape isKindOfClass:[MKPointAnnotation class]]) {
                [annotations addObject:mkShape];
            }
        }
    }];
    
    [self.mapView addAnnotations:annotations];
    [self.mapView addOverlays:overlays];
    
    // set zoom in next run loop.
    dispatch_async(dispatch_get_main_queue(), ^{

        //
        // Thanks for elegant code!
        // https://gist.github.com/915374
        //
        __block MKMapRect zoomRect = MKMapRectNull;
        [self.mapView.annotations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            id<MKAnnotation> annotation = (id<MKAnnotation>)obj;
            MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
            MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
            if (MKMapRectIsNull(zoomRect)) {
                zoomRect = pointRect;
            } else {
                zoomRect = MKMapRectUnion(zoomRect, pointRect);
            }
        }];
        [self.mapView setVisibleMapRect:zoomRect animated:YES];
    });
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    else if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPointAnnotation *pointAnnotation = (MKPointAnnotation *)annotation;
        return [pointAnnotation annotationViewForMapView:mapView];
    }
    
    return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        return [(MKPolyline *)overlay overlayViewForMapView:mapView];
    }
    else if ([overlay isKindOfClass:[MKPolygon class]]) {
        return [(MKPolygon *)overlay overlayViewForMapView:mapView];
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if ([view.annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPointAnnotation *pointAnnotation = (MKPointAnnotation *)view.annotation;
        [self pushDetailViewControllerWithGeometry:pointAnnotation.geometry];
    }
}

@end


#pragma mark - 
@implementation MapViewController (UITableViewDataSource)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchResultView) {
        return self.filteredGeometries.count;
    }
    
    return self.geometries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KMLAbstractGeometry *geometry;
    if (tableView == self.searchResultView) {
        geometry = self.filteredGeometries[indexPath.row];
    } else {
        geometry = self.geometries[indexPath.row];
    }

    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    KMLPlacemark *placemark = geometry.placemark;
    cell.textLabel.text = placemark.name;
    cell.detailTextLabel.text = placemark.snippet;
    
    return cell;
}

@end


#pragma mark - 
@implementation MapViewController (UITableViewDelegate)

- (void)tableViewWillAppear:(UITableView *)tableView
{
    NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
    if (indexPath) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    
    [tableView flashScrollIndicators];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (tableView == self.listView) {
        if (self.kml) {
            return self.kml.name;
        }
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{   
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (tableView == self.searchResultView) {
        [self.placeSearchBar resignFirstResponder];
    }
    
    KMLAbstractGeometry *geometry;
    if (tableView == self.searchResultView) {
        geometry = self.filteredGeometries[indexPath.row];
    } else {
        geometry = self.geometries[indexPath.row];
    }

    // cancel searching
    if (tableView == self.searchResultView) {
        [self searchBarCancelButtonClicked:self.placeSearchBar];
    }

    // flip to mapview
    if (self.listView.superview) {
        [self flip:nil];
    }
    
    // move to the selected annotation
    MKShape *shape = [geometry mapkitShape];

    [self.mapView setCenterCoordinate:shape.coordinate animated:YES];
    if ([shape isKindOfClass:[MKPointAnnotation class]]) {
        [self.mapView selectAnnotation:shape animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    KMLAbstractGeometry *geometry;
    if (tableView == self.searchResultView) {
        geometry = self.filteredGeometries[indexPath.row];
    } else {
        geometry = self.geometries[indexPath.row];
    }
    
    [self pushDetailViewControllerWithGeometry:geometry];
}

@end

