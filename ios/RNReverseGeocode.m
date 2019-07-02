#import <MapKit/MapKit.h>
#import "RNReverseGeocode.h"
#import <React/RCTConvert.h>
#import <CoreLocation/CoreLocation.h>
#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTUtils.h>

#import <AddressBookUI/AddressBookUI.h>
#import <Contacts/Contacts.h>

@interface RCTConvert (Mapkit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json;
+ (MKCoordinateRegion)MKCoordinateRegion:(id)json;

@end

@implementation RCTConvert(MapKit)

+ (MKCoordinateSpan)MKCoordinateSpan:(id)json
{
    json = [self NSDictionary:json];
    return (MKCoordinateSpan){
        [self CLLocationDegrees:json[@"latitudeDelta"]],
        [self CLLocationDegrees:json[@"longitudeDelta"]]
    };
}

+ (MKCoordinateRegion)MKCoordinateRegion:(id)json
{
    return (MKCoordinateRegion){
        [self CLLocationCoordinate2D:json],
        [self MKCoordinateSpan:json]
    };
}

@end

@implementation RNReverseGeocode
{
    MKLocalSearch *localSearch;
    CLGeocoder *geocoder;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

- (NSArray *)formatLocalSearchCallback:(MKLocalSearchResponse *)localSearchResponse
{
    NSMutableArray *RCTResponse = [[NSMutableArray alloc] init];
    
    for (MKMapItem *mapItem in localSearchResponse.mapItems) {
        NSMutableDictionary *formedLocation = [[NSMutableDictionary alloc] init];
        
        [formedLocation setValue:mapItem.name forKey:@"name"];
        [formedLocation setValue:mapItem.placemark.title forKey:@"address"];
        [formedLocation setValue:@{@"latitude": @(mapItem.placemark.coordinate.latitude),
                                   @"longitude": @(mapItem.placemark.coordinate.longitude)} forKey:@"location"];
        
        [RCTResponse addObject:formedLocation];
    }
    
    return [RCTResponse copy];
}

RCT_EXPORT_METHOD(searchForLocations:(NSString *)searchText near:(MKCoordinateRegion)region callback:(RCTResponseSenderBlock)callback)
{
    [localSearch cancel];
    
    MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
    searchRequest.naturalLanguageQuery = searchText;
    searchRequest.region = region;

    localSearch = [[MKLocalSearch alloc] initWithRequest:searchRequest];
    
    __weak RNReverseGeocode *weakSelf = self;
    [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        
        if (error) {
            callback(@[RCTMakeError(@"Failed to make local search. ", error, @{@"key": searchText}), [NSNull null]]);
        } else {
            NSArray *RCTResponse = [weakSelf formatLocalSearchCallback:response];
            callback(@[[NSNull null], RCTResponse]);
        }
    }];
}

RCT_EXPORT_METHOD(searchForLocationsByCoordinate:(double)latitude longitude:(double)longitude callback:(RCTResponseSenderBlock)callback)
{
    if (!geocoder) {
        geocoder = [[CLGeocoder alloc] init];
    }
    
    CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (error) {
            NSLog(@"searchForLocationsByCoordinate - err: %@", error.description);
            callback(@[RCTMakeError(@"Failed to make coordinate search. ", error, @{@"latitude": @(latitude), @"longitude": @(longitude)}), [NSNull null]]);
        } else {
            NSMutableArray *response = [[NSMutableArray alloc] init];
            
            for (CLPlacemark *placemark in placemarks) {
                NSMutableDictionary *formedLocation = [[NSMutableDictionary alloc] init];
                
                [formedLocation setValue:placemark.name forKey:@"name"];
                
                NSString *formattedAddress = @"";
                if (@available(iOS 11.0, *)) {
                    formattedAddress = [[CNPostalAddressFormatter stringFromPostalAddress:placemark.postalAddress style:CNPostalAddressFormatterStyleMailingAddress] stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
                } else {
                    // Fallback on earlier versions
                    formattedAddress = [ABCreateStringWithAddressDictionary(placemark.addressDictionary, YES) stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
                }
                [formedLocation setValue:formattedAddress forKey:@"address"];
                [formedLocation setValue:@{@"latitude": @(placemark.location.coordinate.latitude),
                                           @"longitude": @(placemark.location.coordinate.longitude)} forKey:@"location"];
                
                [response addObject:formedLocation];
            }
            
            callback(@[[NSNull null], [response copy]]);
        }
    }];
}

@end
