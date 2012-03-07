//
//  PhoneKal.m
//  PhoneKal
//
//  Created by Yann Jouanique on 07/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PhoneKal.h"
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import <dispatch/dispatch.h>

static BOOL IsDateBetweenInclusive(NSDate *date, NSDate *begin, NSDate *end)
{
	return [date compare:begin] != NSOrderedAscending && [date compare:end] != NSOrderedDescending;
}

@implementation PhoneKal

@synthesize successCallback,failCallback;

#pragma mark Initialization

-(void)presentPicker:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	NSLog(@"arguments: %@",arguments);
	NSLog(@"dict: %@",options);
	
	//Compute default initial date
	NSDate* initialDate;
	NSString* initialDateString = [options objectForKey:@"initialDate"];
	if(initialDateString) {
		initialDate = [JSDateFormatter dateFromString:initialDateString];
	}
	if(!initialDate) {
		initialDate = [NSDate date];
	}
		
	//compute title
	NSString* title = [options objectForKey:@"title"]? [options objectForKey:@"title"] : @"Select date";
	
	//instantiate the Kal view
	_pick = [[KalViewController alloc] initWithSelectedDate:initialDate];
	_pick.title = title;
	_pick.delegate = self;
	_dataSource = [[EventKitDataSource alloc] init];
	_pick.dataSource = _dataSource;
	
	//wrap it into a NavigationController
	_navController = [[UINavigationController alloc] initWithRootViewController:_pick];
		
	/*
	//display today button?
	if([options objectForKey:@"displayTodayButton"]) {
		_pick.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Today" 
																				  style:UIBarButtonItemStyleBordered
																				 target:self
																				 action:@selector(jumpToToday)];
	}*/

	//cancel button
	_pick.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" 
																			  style:UIBarButtonItemStyleBordered
																			 target:self
																			 action:@selector(cancel)];
	_pick.navigationItem.leftBarButtonItem.tintColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.0 alpha:1.0];
	
	//OK button
	_pick.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" 
																			   style:UIBarButtonItemStyleDone
																			  target:self
																			  action:@selector(submit)];
	
	//present everything
	[[super appViewController] presentViewController:_navController
											animated:YES
										  completion:nil];
}

#pragma mark Submit / cancel logic

-(void)callback:(NSDate*)date
{
	[[super appViewController] dismissModalViewControllerAnimated:YES];

	NSString* jsString = [NSString stringWithFormat:@"window.plugins.PhoneKal.didSelectDate('%@');",[JSDateFormatter formatDate:date]];
	[self writeJavascript:jsString];
}

-(void)cancel
{
	[[super appViewController] dismissModalViewControllerAnimated:YES];
}

-(void)submit
{
	[self callback:_pick.selectedDate];
}

#pragma mark Date Navigation logic

-(void)jumpToToday
{
	[self jumpToDate:[NSDate date]];
}

-(void)jumpToDate:(NSDate*)date
{
	[_pick showAndSelectDate:date];
}


#pragma mark UITableViewDelegate protocol conformance

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Display a details screen for the selected event/row.
	EKEventViewController *vc = [[EKEventViewController alloc] init];
	vc.event = [_dataSource eventAtIndexPath:indexPath];
	vc.allowsEditing = NO;
	[_navController pushViewController:vc animated:YES];
}



@end



@implementation JSDateFormatter;

+(NSString*)formatDate:(NSDate*)date
{
	if(!date) return nil;
	return [[JSDateFormatter formatter] stringFromDate:date];
}

+(NSDate*)dateFromString:(NSString*)date
{
	if(!date) return nil;
	return [[JSDateFormatter formatter] dateFromString:date];
}

+(NSDateFormatter*)formatter
{
	NSDateFormatter* df = [[NSDateFormatter alloc] init];
	df.locale = [NSLocale systemLocale];
	df.dateFormat = @"yyyy'-'M'-'d";
	return df;
}
@end


@interface EventKitDataSource ()
- (NSArray *)eventsFrom:(NSDate *)fromDate to:(NSDate *)toDate;
- (NSArray *)markedDatesFrom:(NSDate *)fromDate to:(NSDate *)toDate;
@end


@implementation EventKitDataSource

+ (EventKitDataSource *)dataSource
{
	return [[[self class] alloc] init];
}

- (id)init
{
	if ((self = [super init])) {
		eventStore = [[EKEventStore alloc] init];
		events = [[NSMutableArray alloc] init];
		items = [[NSMutableArray alloc] init];
		eventStoreQueue = dispatch_queue_create("com.thepolypeptides.nativecalexample", NULL);
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventStoreChanged:) name:EKEventStoreChangedNotification object:nil];
	}
	return self;
}

- (void)eventStoreChanged:(NSNotification *)note
{
	[[NSNotificationCenter defaultCenter] postNotificationName:KalDataSourceChangedNotification object:nil];
}

- (EKEvent *)eventAtIndexPath:(NSIndexPath *)indexPath
{
	return [items objectAtIndex:indexPath.row];
}

#pragma mark UITableViewDataSource protocol conformance

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *identifier = @"MyCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
	}
	
	EKEvent *event = [self eventAtIndexPath:indexPath];
	cell.textLabel.text = event.title;
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.minimumFontSize = 9.0;
	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [items count];
}

#pragma mark KalDataSource protocol conformance

- (void)presentingDatesFrom:(NSDate *)fromDate to:(NSDate *)toDate delegate:(id<KalDataSourceCallbacks>)delegate
{
	// asynchronous callback on the main thread
	[events removeAllObjects];
	NSLog(@"Fetching events from EventKit between %@ and %@ on a GCD-managed background thread...", fromDate, toDate);
	dispatch_async(eventStoreQueue, ^{
		//NSDate *fetchProfilerStart = [NSDate date];
		NSPredicate *predicate = [eventStore predicateForEventsWithStartDate:fromDate endDate:toDate calendars:nil];
		NSArray *matchedEvents = [eventStore eventsMatchingPredicate:predicate];
		dispatch_async(dispatch_get_main_queue(), ^{
			//NSLog(@"Fetched %d events in %f seconds", [matchedEvents count], -1.f * [fetchProfilerStart timeIntervalSinceNow]);
			[events addObjectsFromArray:matchedEvents];
			[delegate loadedDataSource:self];
		});
	});
}

- (NSArray *)markedDatesFrom:(NSDate *)fromDate to:(NSDate *)toDate
{
	// synchronous callback on the main thread
	return [[self eventsFrom:fromDate to:toDate] valueForKeyPath:@"startDate"];
}

- (void)loadItemsFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
	// synchronous callback on the main thread
	[items addObjectsFromArray:[self eventsFrom:fromDate to:toDate]];
}

- (void)removeAllItems
{
	// synchronous callback on the main thread
	[items removeAllObjects];
}

- (NSArray *)eventsFrom:(NSDate *)fromDate to:(NSDate *)toDate
{
	NSMutableArray *matches = [NSMutableArray array];
	for (EKEvent *event in events)
		if (IsDateBetweenInclusive(event.startDate, fromDate, toDate))
			[matches addObject:event];
	
	return matches;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:EKEventStoreChangedNotification object:nil];
}

@end
