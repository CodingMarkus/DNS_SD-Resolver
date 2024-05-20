@import Foundation;

#import "DNS_SD.h"
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
void test_ipv4Address_any( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"127.0.0.1"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_Any
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
	[resolver activate];
}


static
void test_ipv4Address_ipv4( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"192.168.1.1"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_IPv4Only
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
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_NoMoreResults
			);
			test_assert(!resolver.isActive);

			let equal = [collectedResults isEqual:@[ @"192.168.1.1" ]];
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
void test_ipv4Address_ipv6( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"127.0.0.1"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_IPv6Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(ipAddresses.count != 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_CancelTimeoutHit
			);
			test_assert(!resolver.isActive);

			test_assert_fmt(
				collectedResults.count == 0,
				@"Collected: %@", collectedResults
			);

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
void test_ipv4Address( )
{
	@autoreleasepool {  test_ipv4Address_any( ); }
	@autoreleasepool {  test_ipv4Address_ipv4( ); }
	@autoreleasepool {  test_ipv4Address_ipv6( ); }
}


static
void test_ipv6Address_any( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver resolverFor:@"::"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_Any
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(collectedResults.count == 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_NoMoreResults
			);
			test_assert(!resolver.isActive);

			let equal = [collectedResults isEqual:@[ @"::" ]];
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
void test_ipv6Address_ipv6( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver
		resolverFor:@"2001:db8:0:8d3:0:8a2e:70:7344"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_IPv6Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				test_assert(collectedResults.count == 0);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_NoMoreResults
			);
			test_assert(!resolver.isActive);

			let equal = [collectedResults
				isEqual:@[ @"2001:db8:0:8d3:0:8a2e:70:7344" ]
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
void test_ipv6Address_ipv4( )
{
	__block let collectedResults = [NSMutableArray array];
	__block let keepResolverAlive = [NSMutableArray array];

	let resolver = [DNS_SD_Resolver
		resolverFor:@"2001:db8:0:8d3:0:8a2e:70:7344"
		timeouts:DNS_SD_Timeouts_Make(0, 0, 5) versionFilter:DNS_SD_IPv4Only
		callbackQueue:dispatch_get_main_queue()
		callback:^(
			DNS_SD_Resolver * resolver,
			NSError *_Nullable error,
			NSArray <NSString *> *_Nullable ipAddresses )
		{
			if (!error) {
				test_assert(ipAddresses);
				[collectedResults addObjectsFromArray:(NSArray *)ipAddresses];
				return;
			}

			test_assert(!ipAddresses);
			test_assert_error(error,
				DNS_SD_Resolver_ErrorDomain, DNS_SD_Error_CancelTimeoutHit
			);
			test_assert(!resolver.isActive);

			test_assert_fmt(
				collectedResults.count == 0,
				@"Collected: %@", collectedResults
			);

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
void test_ipv6Address( )
{
	@autoreleasepool {  test_ipv6Address_any(); }
	@autoreleasepool {  test_ipv6Address_ipv4(); }
	@autoreleasepool {  test_ipv6Address_ipv6(); }
}


static
void test_ipDetection( )
{
	struct {
		const char * address;
		bool isIP;
		bool isIPv4;
		bool isIPv6;
	} addresses[ ] = {
		{ "", false, false, false },
		{ " ", false, false, false },
		{ "192.168.1.1", true, true, false },
		{ "127.0.0.1", true, true, false },
		{ "::", true, false, true },
		{ "2001:db8:0:8d3:0:8a2e:70:7344", true, false, true },
		{ "test.com", false, false, false }
	};

	let addressCount = sizeof(addresses) / sizeof(addresses[0]);

	for (size_t i = 0; i < addressCount; i++) {
		let addr = addresses[i];
		let addrStr = (NSString *)@(addr.address);
		test_assert_fmt(
			[DNS_SD_Resolver isIPAddress:addrStr] == addr.isIP,
			@"%s", addr.address
		);
		test_assert_fmt(
			[DNS_SD_Resolver isIPv4Address:addrStr] == addr.isIPv4,
			@"%s", addr.address
		);
		test_assert_fmt(
			[DNS_SD_Resolver isIPv6Address:addrStr] == addr.isIPv6,
			@"%s", addr.address
		);
	}
}


static
void runAllTests( )
{
	@autoreleasepool { test_ipv4Address(); }
	@autoreleasepool { test_ipv6Address(); }
	@autoreleasepool { test_ipDetection(); }
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
