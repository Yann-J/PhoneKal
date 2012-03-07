//
//  PhoneKal.h
//  PhoneKal
//
//  Created by Yann Jouanique on 07/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PhoneGap/PGPlugin.h>
#import "Kal.h"

@class EKEventStore, EKEvent, EventKitDataSource,PhoneKalView;


@interface PhoneKal : PGPlugin <UITableViewDelegate> {
	NSString* _successCallback;
	NSString* _failCallback;
	EventKitDataSource* _dataSource;
	UINavigationController* _navController;
	KalViewController* _pick;
}

@property (nonatomic, copy) NSString* successCallback;
@property (nonatomic, copy) NSString* failCallback;

-(void)presentPicker:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void)callback:(NSDate*)date;
-(void)cancel;
-(void)submit;
-(void)jumpToToday;
-(void)jumpToDate:(NSDate*)date;


@end


@interface JSDateFormatter : NSObject

+(NSString*)formatDate:(NSDate*)date;
+(NSDate*)dateFromString:(NSString*)date;
+(NSDateFormatter*)formatter;

@end


@interface EventKitDataSource : NSObject <KalDataSource>
{
	NSMutableArray *items;            // The list of events corresponding to the currently selected day in the calendar. These events are used to configure cells vended by the UITableView below the calendar month view.
	NSMutableArray *events;           // Must be used on the main thread
	EKEventStore *eventStore;         // Must be used on a background thread managed by eventStoreQueue
	dispatch_queue_t eventStoreQueue; // Serializes access to eventStore and offloads the query work to a background thread.
}

+ (EventKitDataSource *)dataSource;
- (EKEvent *)eventAtIndexPath:(NSIndexPath *)indexPath;  // exposed for client so that it can implement the UITableViewDelegate protocol.

@end
