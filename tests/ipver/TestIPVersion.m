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
void test_ipv4( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"dns.google"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 4) versionFilter:DNS_SD_IPv4Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			test_assert_fmt(!error, @"Unecpected error: %@", error);

			test_assert(ipAddresses);
			if (ipAddresses.count != 0) {
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				if (collectedResults.count == 2) [resolver cancel];
				return;
			}

			test_assert(ipAddresses);
			test_assert(ipAddresses.count == 0);
			test_assert(!resolver.isActive);

			let equal = [[NSSet setWithArray:collectedResults]
				isEqual:[NSSet setWithArray:
					@[ @"8.8.8.8", @"8.8.4.4" ]
				]
			];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[resolver activate];
}



static
void test_ipv6( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"dns.google"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 4) versionFilter:DNS_SD_IPv6Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			test_assert_fmt(!error, @"Unecpected error: %@", error);

			test_assert(ipAddresses);
			if (ipAddresses.count != 0) {
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				if (collectedResults.count == 2) [resolver cancel];
				return;
			}

			test_assert(ipAddresses);
			test_assert(ipAddresses.count == 0);
			test_assert(!resolver.isActive);

			let equal = [[NSSet setWithArray:collectedResults]
				isEqual:[NSSet setWithArray:
					@[ @"2001:4860:4860::8888", @"2001:4860:4860::8844"	]
				]
			];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[resolver activate];
}


static
void test_ipAny( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"dns.google"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 6) versionFilter:DNS_SD_Any
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			test_assert_fmt(!error, @"Unecpected error: %@", error);

			test_assert(ipAddresses);
			if (ipAddresses.count != 0) {
				test_assert(ipAddresses.count != 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				if (collectedResults.count == 4) [resolver cancel];
				return;
			}

			test_assert(ipAddresses);
			test_assert(ipAddresses.count == 0);
			test_assert(!resolver.isActive);

			let equal = [[NSSet setWithArray:collectedResults]
				isEqual:[NSSet setWithArray:
					@[ @"8.8.8.8", @"8.8.4.4",
						@"2001:4860:4860::8888", @"2001:4860:4860::8844"
					]
				]
			];
			test_assert_fmt(equal, @"Collected: %@", collectedResults);

			[keepResolverAlive removeAllObjects];
			pendingTests--;
		}
	];
	test_assert(resolver);
	[keepResolverAlive addObject:resolver];
	pendingTests++;
	[resolver activate];
}


static
void runAllTests( )
{
	@autoreleasepool { test_ipv4(); }
	@autoreleasepool { test_ipv6(); }
	@autoreleasepool { test_ipAny(); }
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
