@import Foundation;

#import "DNS_SD.h"
#import "TestWatch.h"
#import "TestAssert.h"

#define var __auto_type
#define let const var

_Pragma("clang assume_nonnull begin")
// ============================================================================

static var pendingTests = 0;

static
void waitForPendingTests( )
{
	if (pendingTests == 0) exit(0);

	dispatch_after(
		dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
		dispatch_get_main_queue(),
		^{
			waitForPendingTests();
		}
	);
}


static
void test_waitAndCancelTimeout( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	__block let watch = [TestWatch new];

	let resolver = [DNS_SD_Resolver resolverFor:@"www.example.com"
		timeouts:DNS_SD_Timeouts_Make(3, 0, 6) versionFilter:DNS_SD_IPv4Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(ipAddresses.count != 0);
				test_assert(collectedResults.count == 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];

				let timePassed = [watch stop];
				test_assert(timePassed >= 3);

				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_CancelTimeoutHit
			);
			test_assert(!resolver.isActive);

			let timePassed = [watch stop];
			test_assert_fmt(timePassed >= 6, @"%@ < 6", @(timePassed));


			let equal = [collectedResults isEqual:@[ @"93.184.216.34" ]];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[watch start];
	[resolver activate];
}


static
void test_noWaitTimeoutForIP( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	__block let watch = [TestWatch new];

	let resolver = [DNS_SD_Resolver resolverFor:@"127.0.0.1"
		timeouts:DNS_SD_Timeouts_Make(3, 0, 6) versionFilter:DNS_SD_Any
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(ipAddresses.count != 0);
				test_assert(collectedResults.count == 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];

				let timePassed = [watch stop];
				test_assert(timePassed < 5);

				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_NoMoreResults
			);
			test_assert(!resolver.isActive);

			let equal = [collectedResults isEqual:@[ @"127.0.0.1" ]];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[watch start];
	[resolver activate];
}


static
void test_updateTimeout( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	__block let watch = [TestWatch new];

	let resolver = [DNS_SD_Resolver resolverFor:@"www.example.com"
		timeouts:DNS_SD_Timeouts_Make(0, 3, 6) versionFilter:DNS_SD_IPv4Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(ipAddresses.count != 0);
				test_assert(collectedResults.count == 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_UpdateTimeoutHit
			);
			test_assert(!resolver.isActive);

			let timePassed = [watch stop];
			test_assert_fmt(timePassed < 6, @"%@ >= 6", @(timePassed));

			let equal = [collectedResults isEqual:@[ @"93.184.216.34" ]];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[watch start];
	[resolver activate];
}


static
void runAllTests( )
{
	@autoreleasepool { test_waitAndCancelTimeout(); }
	@autoreleasepool { test_noWaitTimeoutForIP(); }
	@autoreleasepool { test_updateTimeout(); }
	waitForPendingTests();
}


int
main( int argc, const char *_Nonnull argv[] )
{
	@autoreleasepool {
		let mq = dispatch_get_main_queue();
		dispatch_async(mq, ^{  runAllTests();  });
		dispatch_main();
	}
	return 0;
}

// ============================================================================
_Pragma("clang assume_nonnull end")
