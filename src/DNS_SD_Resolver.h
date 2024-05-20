#import <Foundation/Foundation.h>
_Pragma("clang assume_nonnull begin")
// ============================================================================
// MARK: IP Filter

enum __attribute__((enum_extensibility(closed)))
	DNS_SD_IPVersionFilter
{
	// Only return results for IP versions currently supported by the system.
	// Note: For IP address strings, this behaves like "Any".
	DNS_SD_Supported = -1,

	DNS_SD_Any       =  0,
	DNS_SD_IPv4Only  =  4,
	DNS_SD_IPv6Only  =  6
};

// ----------------------------------------------------------------------------
// MARK: Timeouts

struct DNS_SD_Timeouts {
	/// Wait at least that long for results to come in before reporting
	/// any result, unless lookup failed. If 0 or negative, there is no
	/// minimum wait time and results are delivered immediately when available.
	NSTimeInterval waitTimeout;

	/// Cancel automatically if no update has been arrived for that amount of
	/// time after the first result arrived. If 0 or negative, resolver will
	/// continue until  canceled by the @c cancelTimeout or calling @c -cancel.
	NSTimeInterval updateTimeout;

	/// Cancel automatically after that much time has passed. If 0 or negative
	/// there is no cancel timeout and the resolver will continue until
	/// canceled by the @c updateTimeout or calling @c -cancel.
	NSTimeInterval cancelTimeout;
};


#define DNS_SD_Timeouts_Make( w, u, c ) \
	((struct DNS_SD_Timeouts){ w, u, c })


// ----------------------------------------------------------------------------
// MARK: Callback

@class DNS_SD_Resolver;

typedef void (^ DNS_SD_Callback)(
	DNS_SD_Resolver * resolver,
	NSError *_Nullable error,
	/// If empty, resolver has been canceled and
	/// the callback won't ever get called again.
	NSArray <NSString *> *_Nullable ipAddresses
);

// ----------------------------------------------------------------------------
// MARK: Resolver Class

__attribute__((objc_subclassing_restricted))
@interface DNS_SD_Resolver : NSObject

	@property(readonly) NSString * domainOrIPAddress;
	@property(readonly) struct DNS_SD_Timeouts timeouts;
	@property(readonly) enum DNS_SD_IPVersionFilter versionFilter;
	@property(readonly) dispatch_queue_t queue;

	/// As long as the resolver is still active, it will continue to deliver
	/// results. A resolver becomes inactive because of an error, a timeout,
	/// or because it was canceled.
	@property(readonly) BOOL isActive;

	/// If canceled by an error, this is the error.
	@property(readonly) NSError *_Nullable cancledByError;

	/// Start performing DNS lookups until there is an error
	/// or cancel is being called.
	- (void)activate;

	/// If there are pending addresses not yet delivered, those are still
	/// deliverd before the resolver is canceled. No more results will be
	/// delivered, until the resolver is re-activated.
	- (void)cancel;


	/// Test if @c domainOrIPAddress can be parsed as an IP address.
	+ (BOOL)isIPAddress:(NSString *)domainOrIPAddress;

	/// Test if @c domainOrIPAddress can be parsed as an IPv4 address.
	+ (BOOL)isIPv4Address:(NSString *)domainOrIPAddress;

	/// Test if @c domainOrIPAddress can be parsed as an IPv6 address.
	+ (BOOL)isIPv6Address:(NSString *)domainOrIPAddress;


	/// @param queue If @c nil, the main queue will be used.
	+ (DNS_SD_Resolver *)resolverFor:(NSString *)domainOrIPAddress
		timeouts:(struct DNS_SD_Timeouts)touts
		versionFilter:(enum DNS_SD_IPVersionFilter)vfilter
		callbackQueue:(dispatch_queue_t _Nullable)queue
		callback:(DNS_SD_Callback)callback;


	+ (instancetype)new __attribute__((unavailable));

	- (instancetype)init __attribute__((unavailable));

@end

// ----------------------------------------------------------------------------
// MARK: Errors

extern __attribute__((swift_name("DNS_SD_Resolver.ErrorDomain")))
	NSErrorDomain const DNS_SD_Resolver_ErrorDomain;

enum __attribute__((ns_error_domain(DNS_SD_Resolver_ErrorDomain)))
	__attribute__((swift_name("DNS_SD_Resolver.Error")))
	DNS_SD_Resolver_Error : NSInteger
{
	/// Internal system error, see underlying error for details.
	DNS_SD_Resolver_Error_System,

	/// Resolver was canceled because the @c updateTimeout has been hit.
	DNS_SD_Resolver_Error_UpdateTimeoutHit,

	/// Resolver was canceled because the @c cancelTimeout has been hit.
	DNS_SD_Resolver_Error_CancelTimeoutHit,

	/// Resolver canceled itself as no more results can be expected.
	DNS_SD_Resolver_Error_NoMoreResults,

	/// Resolver was canceled because DNS querying timed out.
	DNS_SD_Resolver_Error_SystemTimeout,

	/// Domain not found in DNS system.
	DNS_SD_Resolver_Error_NoSuchDomain,

	/// Domain has been found but there is no entry for the requested
	/// address record (e.g. IPv6 was requested by there is only IPv4).
	DNS_SD_Resolver_Error_NoSuchAddress,
};

// ============================================================================
_Pragma("clang assume_nonnull end")
