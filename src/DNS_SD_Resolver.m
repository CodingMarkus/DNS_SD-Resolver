#import "DNS_SD_Resolver.h"

#import <netdb.h>
#import <dns_sd.h>
#import <sys/socket.h>
#import <arpa/inet.h>

#define var __auto_type
#define let const var

_Pragma("clang assume_nonnull begin")
// ============================================================================

static
NSError * createWrappedError(
	enum DNS_SD_Resolver_Error code,
	const char * name, NSError *_Nullable underlying )
{
	let desc = [NSString stringWithFormat:@"DNS SD Error: %s", name];

	let userInfo = (underlying ?
		@{
			NSUnderlyingErrorKey: (NSError *)underlying,
			NSLocalizedDescriptionKey: desc
		}
		:
		@{
			NSLocalizedDescriptionKey: desc
		}
	);


	return [NSError errorWithDomain:DNS_SD_Resolver_ErrorDomain
		code:code userInfo:userInfo
	];
}


static
NSError * createDNSServiceError( DNSServiceErrorType dnsError )
{
	var name = "System";
	enum DNS_SD_Resolver_Error code = DNS_SD_Resolver_Error_System;

	switch (dnsError) {
		case kDNSServiceErr_Unknown:
		case kDNSServiceErr_NoMemory:
		case kDNSServiceErr_BadParam:
		case kDNSServiceErr_BadReference:
		case kDNSServiceErr_BadState:
		case kDNSServiceErr_BadFlags:
		case kDNSServiceErr_Unsupported:
		case kDNSServiceErr_NotInitialized:
		case kDNSServiceErr_AlreadyRegistered:
		case kDNSServiceErr_NameConflict:
		case kDNSServiceErr_Invalid:
		case kDNSServiceErr_Firewall:
		case kDNSServiceErr_Incompatible:
		case kDNSServiceErr_BadInterfaceIndex:
		case kDNSServiceErr_Refused:
		case kDNSServiceErr_NoAuth:
		case kDNSServiceErr_NoSuchKey:
		case kDNSServiceErr_NATTraversal:
		case kDNSServiceErr_DoubleNAT:
		case kDNSServiceErr_BadTime:
		case kDNSServiceErr_BadSig:
		case kDNSServiceErr_BadKey:
		case kDNSServiceErr_Transient:
		case kDNSServiceErr_ServiceNotRunning:
		case kDNSServiceErr_NATPortMappingUnsupported:
		case kDNSServiceErr_NATPortMappingDisabled:
		case kDNSServiceErr_NoRouter:
		case kDNSServiceErr_PollingMode:
		case kDNSServiceErr_DefunctConnection:
		case kDNSServiceErr_PolicyDenied:
		case kDNSServiceErr_NotPermitted:
			break;

		case kDNSServiceErr_NoSuchName:
			name = "NoSuchDomain";
			code = DNS_SD_Resolver_Error_NoSuchDomain;
			break;

		case kDNSServiceErr_NoSuchRecord:
			name = "NoSuchAddress";
			code = DNS_SD_Resolver_Error_NoSuchAddress;
			break;

		case kDNSServiceErr_Timeout:
			name = "Timeout";
			code = DNS_SD_Resolver_Error_SystemTimeout;
			break;
	}

	let underlying = [NSError
		errorWithDomain:NSOSStatusErrorDomain code:dnsError userInfo:nil
	];
	return createWrappedError(code, name, underlying);
}


static
NSError * createError( enum DNS_SD_Resolver_Error code, const char * name )
{
	return createWrappedError(code, name, nil);
}


#define createError( code ) \
	createError(DNS_SD_Resolver_Error_ ## code, #code)


static
bool isIPv4Address( NSString * str )
{
	uint8_t buffer[4];
	let testRes = inet_pton(AF_INET, str.UTF8String, buffer);
	return (testRes == 1);
}


static
bool isIPv6Address( NSString * str )
{
	uint8_t buffer[16];
	let testRes = inet_pton(AF_INET6, str.UTF8String, buffer);
	return (testRes == 1);
}



// ----------------------------------------------------------------------------

__attribute__((objc_direct_members))
@implementation DNS_SD_Resolver
	{
		DNS_SD_Callback _callback;
		struct DNS_SD_Timeouts _timeouts;

		NSRecursiveLock * _lock;
		NSMutableArray * _collectedAdresses;

		dispatch_source_t _Nullable _waitTimer;
		dispatch_source_t _Nullable _updateTimer;
		dispatch_source_t _Nullable _cancelTimer;

		DNSServiceRef _Nullable _serviceRef;
	}

	- (BOOL)isActive
	{
		var result = YES;
		[_lock lock];
		result = (_serviceRef != NULL);
		[_lock unlock];
		return result;
	}


	// ------------------------------------------------------------------------

	- (struct DNS_SD_Timeouts)timeouts
	{
		struct DNS_SD_Timeouts result = _timeouts;
		return result;
	}


	- (void)activate
	{
		[self scheduleWaitTimeout];
		[self scheduleCancelTimeout];
		[self setupService];
	}


	- (void)cancel
	{
		[self cancelWithError:nil];
	}



	+ (BOOL)isIPAddress:(NSString *)domainOrIPAddress
	{
		return (
			isIPv4Address(domainOrIPAddress)
			|| isIPv6Address(domainOrIPAddress)
		);
	}


	+ (BOOL)isIPv4Address:(NSString *)domainOrIPAddress
	{
		return isIPv4Address(domainOrIPAddress);
	}


	+ (BOOL)isIPv6Address:(NSString *)domainOrIPAddress
	{
		return isIPv6Address(domainOrIPAddress);
	}



	+ (DNS_SD_Resolver *)resolverFor:(NSString *)domainOrIPAddress
		timeouts:(struct DNS_SD_Timeouts)touts
		versionFilter:(enum DNS_SD_IPVersionFilter)vfilter
		callbackQueue:(dispatch_queue_t _Nullable)queue
		callback:(DNS_SD_Callback)callback
	{
		let resolver = [[DNS_SD_Resolver alloc]
			initWithAddress:domainOrIPAddress
			timeouts:touts
			versionFilter:vfilter
			callbackQueue:(queue ?: dispatch_get_main_queue())
			callback:callback
		];
		return resolver;
	}


	- (instancetype)initWithAddress:(NSString *)address
		timeouts:(struct DNS_SD_Timeouts)touts
		versionFilter:(enum DNS_SD_IPVersionFilter)vfilter
		callbackQueue:(dispatch_queue_t)queue
		callback:(DNS_SD_Callback)callback
	{
		self = [super init];

		_domainOrIPAddress = [address copy];
		_timeouts = touts;
		_versionFilter = vfilter;
		_queue = queue;
		_callback = callback;

		_lock = [NSRecursiveLock new];
		_collectedAdresses = [NSMutableArray arrayWithCapacity:4];

		return self;
	}


	- (void)dealloc
	{
		[self cancel];
	}

	// ------------------------------------------------------------------------

	- (void)sendCollectedAddresses
	{
		[_lock lock];
		if (_collectedAdresses.count > 0) {
			let collected = (NSArray *)[_collectedAdresses copy];
			dispatch_async(_queue, ^{
				self->_callback(self, nil, collected);
			});
			[_collectedAdresses removeAllObjects];
		}
		[_lock unlock];
	}


	- (void)cancelUpdateTimeout
	{
		[_lock lock];
		if (_updateTimer) {
			dispatch_source_cancel((dispatch_source_t)_updateTimer);
			_updateTimer = nil;
		}
		[_lock unlock];
	}


	- (void)cancelAllTimers
	{
		[_lock lock];
		if (_waitTimer) {
			dispatch_source_cancel((dispatch_source_t)_waitTimer);
			_waitTimer = nil;
		}
		if (_cancelTimer) {
			dispatch_source_cancel((dispatch_source_t)_cancelTimer);
			_cancelTimer = nil;
		}
		[self cancelUpdateTimeout];
		[_lock unlock];
	}


	- (void)cancelWithError:(NSError *_Nullable)error
	{
		[_lock lock];
		if (_serviceRef) {
			DNSServiceRefDeallocate(_serviceRef);
			_serviceRef = NULL;

			[self sendCollectedAddresses];
			dispatch_async(_queue, ^{
				if (error) {
					self->_callback(self, error, nil);
				} else {
					self->_callback(self, nil, @[ ]);
				}
			});
		}
		[self cancelAllTimers];
		[_lock unlock];
	}


	static
	int64_t timeIntervalAsNanoseconds( NSTimeInterval intv )
	{
		return (int64_t)(intv * NSEC_PER_SEC);
	}


	- (dispatch_source_t)createTimer:(NSTimeInterval)timeout
		callback:(dispatch_block_t)callback
	{
		let timer = dispatch_source_create(
			DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue
		);
		dispatch_time_t dtime = dispatch_time(
			DISPATCH_TIME_NOW,
			timeIntervalAsNanoseconds(timeout)
		);
		dispatch_source_set_timer(
			timer, dtime, DISPATCH_TIME_FOREVER,
			(uint64_t)timeIntervalAsNanoseconds(0.001)
		);
		dispatch_source_set_event_handler(timer, callback);
		if (@available(macos 10.12, iOS 10.0, *)) {
			dispatch_activate(timer);
		} else {
			dispatch_resume(timer);
		}
		return timer;
	}


	- (void)scheduleWaitTimeout
	{
		if (_timeouts.waitTimeout <= 0) return;

		__weak let wself = self;
		let timer = [self createTimer:_timeouts.waitTimeout
			callback:^{
				__strong let sself = wself;
				if (!sself) return;

				[sself->_lock lock];
				sself->_waitTimer = nil;
				[sself sendCollectedAddresses];
				[sself->_lock unlock];
			}
		];
		_waitTimer = timer;
	}


	- (void)scheduleUpdateTimeout
	{
		if (_timeouts.updateTimeout <= 0) return;

		__weak let wself = self;
		let timer = [self createTimer:_timeouts.updateTimeout
			callback:^{
				__strong let sself = wself;
				[sself cancelWithError:createError(UpdateTimeoutHit)];
			}
		];
		_waitTimer = timer;
	}


	- (void)scheduleCancelTimeout
	{
		if (_timeouts.cancelTimeout <= 0) return;

		__weak let wself = self;
		let timer = [self createTimer:_timeouts.cancelTimeout
			callback:^{
				__strong let sself = wself;
				[sself cancelWithError:createError(CancelTimeoutHit)];
			}
		];
		_cancelTimer = timer;
	}


	- (void)addResult:(NSString *)result more:(BOOL)haveMore
	{
		[_lock lock];
		[_collectedAdresses addObject:result];
		if (!haveMore && !_waitTimer) {
			[self sendCollectedAddresses];
		}
		[self cancelUpdateTimeout];
		[self scheduleUpdateTimeout];
		[_lock unlock];
	}


	- (void)setupService
	{
		DNSServiceProtocol protocol = 0;
		switch (_versionFilter) {
			case DNS_SD_Supported: break;
			case DNS_SD_IPv4Only: protocol = kDNSServiceProtocol_IPv4; break;
			case DNS_SD_IPv6Only: protocol = kDNSServiceProtocol_IPv6; break;
			case DNS_SD_Any:
				protocol = (
					kDNSServiceProtocol_IPv4
					| kDNSServiceProtocol_IPv6
				);
				break;
		}

		if (_versionFilter == DNS_SD_Any
			|| _versionFilter == DNS_SD_Supported
			|| _versionFilter == DNS_SD_IPv4Only)
		{
			if (isIPv4Address(_domainOrIPAddress)) {
				[self addResult:_domainOrIPAddress more:NO];
				[self sendCollectedAddresses];
				dispatch_async(_queue, ^{
					self->_callback(self, createError(NoMoreResults), nil);
				});
				return;
			}
		}

		if (_versionFilter == DNS_SD_Any
			|| _versionFilter == DNS_SD_Supported
			|| _versionFilter == DNS_SD_IPv6Only)
		{
			if (isIPv6Address(_domainOrIPAddress)) {
				[self addResult:_domainOrIPAddress more:NO];
				[self sendCollectedAddresses];
				dispatch_async(_queue, ^{
					self->_callback(self, createError(NoMoreResults), nil);
				});
				return;
			}
		}

		let error = DNSServiceGetAddrInfo(
			&_serviceRef, 0, 0, protocol,
			_domainOrIPAddress.UTF8String,
			&serviceCallback, (__bridge void *)self
		);

		if (error != kDNSServiceErr_NoError) {
			dispatch_async(_queue, ^{
				self->_callback(self, createDNSServiceError(error), nil);
			});
			return;
		}

		DNSServiceSetDispatchQueue(_serviceRef, _queue);
	}


	// ------------------------------------------------------------------------

	static
	void serviceCallback(
		DNSServiceRef service, DNSServiceFlags flags, uint32_t interfaceIndex,
		DNSServiceErrorType errorCode, const char * hostname,
		const struct sockaddr * address, uint32_t ttl, void * context )
	{
		let self = (__bridge DNS_SD_Resolver *)context;

		if (errorCode) {
			[self cancelWithError:createDNSServiceError(errorCode)];
			return;
		}

		// convert sockaddr to IP address string
		char buf[INET6_ADDRSTRLEN + 1];
		if (address->sa_family == AF_INET) {
			inet_ntop(
				AF_INET, &((struct sockaddr_in *)address)->sin_addr,
				buf, sizeof(buf)
			);
		} else {
			inet_ntop(
				AF_INET6, &((struct sockaddr_in6 *)address)->sin6_addr,
				buf, sizeof(buf)
			);
		}

		if (strncmp(buf, "", sizeof(buf)) != 0) {
			let strBuf = @(buf);
			if (strBuf) {
				[self addResult:(NSString *)strBuf
					more:((flags & kDNSServiceFlagsMoreComing) != 0)
				];
			}
		}

	}

@end

// ----------------------------------------------------------------------------

NSErrorDomain const DNS_SD_Resolver_ErrorDomain =
	@"DNS_SD_Resolver_ErrorDomain";

// ============================================================================
_Pragma("clang assume_nonnull end")
