//
//  KMLPolygon+MapKit.m
//  KML+MapKit
//
//  Created by NextBusinessSystem on 11/12/01.
//  Copyright (c) 2011 NextBusinessSystem Co., Ltd. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "KMLCoordinate.h"
#import "KMLLinearRing.h"
#import "KMLPlacemark.h"
#import "KMLStyle.h"
#import "KMLLineStyle.h"
#import "KMLPolyStyle.h"
#import "MKShape+KML.h"
#import "KMLPolygon+MapKit.h"
#import "KMLAbstractGeometry+MapKit.h"

@implementation KMLPolygon (MapKit)

- (MKShape *)mapkitShape
{
    NSArray *outerCoordinates = self.outerBoundaryIs.coordinates;
    
    if (outerCoordinates.count > 0) {
        CLLocationCoordinate2D coors[outerCoordinates.count];
        
        int i = 0;
        for (KMLCoordinate *coordinate in outerCoordinates) {
            coors[i] = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude);
            i++;
        }

        // inner boundaries:
        NSMutableArray *innerBoundariesPolygons = [NSMutableArray new];
        for (KMLLinearRing *innerBoundary in self.innerBoundaryIsList) {
            NSArray *innerCoordinates = innerBoundary.coordinates;
            if (innerCoordinates.count > 0) {
                CLLocationCoordinate2D innerCoors[innerCoordinates.count];
                int cnt = 0;
                for (KMLCoordinate *coordinate in innerCoordinates) {
                    innerCoors[cnt] = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude);
                    cnt++;
                }
                MKPolygon *innerPolygon = [MKPolygon polygonWithCoordinates:innerCoors count:innerCoordinates.count];
                [innerBoundariesPolygons addObject:innerPolygon];
            }
        }

        MKPolygon *polygon;
        if ([innerBoundariesPolygons count] > 0) {
            polygon = [MKPolygon polygonWithCoordinates:coors count:outerCoordinates.count interiorPolygons:innerBoundariesPolygons];
        }
        else {
            polygon = [MKPolygon polygonWithCoordinates:coors count:outerCoordinates.count];
        }
        polygon.geometry = self;
        return polygon;
    }
    
    return nil;
}

- (MKOverlayView *)overlayViewForMapView:(MKMapView *)mapView overlay:(id<MKOverlay>)overlay
{
    MKPolygonView *overlayView = [[MKPolygonView alloc] initWithOverlay:overlay];
    
    KMLPlacemark *placemark = self.placemark;

    KMLPolyStyle *polyStyle = [KMLPolyStyle new];
    KMLLineStyle *lineStyle = [KMLLineStyle new];

    KMLStyle *style = [placemark styleForState:KMLStyleStateNormal];
    if (!style) {
        style = placemark.style;
    }
    if (style) {
        if (style.polyStyle) {
            polyStyle = style.polyStyle;
        }
        if (style.lineStyle) {
            lineStyle = style.lineStyle;
        }
    }
    
    if (polyStyle.fill) {
        overlayView.fillColor = polyStyle.UIColor;
    }

    if (polyStyle.outline) {
        overlayView.strokeColor = lineStyle.UIColor;
        overlayView.lineWidth = lineStyle.width;
    }
    
    return overlayView;
}

@end
