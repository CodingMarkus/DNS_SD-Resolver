@import Foundation;

#import <Foundation/Foundation.h>
_Pragma("clang assume_nonnull begin")
// ============================================================================

#define test_assert_fmt( condition, fmt, ... ) \
	({ \
		if (!(condition)) { \
			NSString * assertMsg = [NSString \
				stringWithFormat:fmt, ##__VA_ARGS__ \
			]; \
			fprintf(stderr, "%s:%d: %s\n", \
				__FUNCTION__, __LINE__, assertMsg.UTF8String \
			); \
			abort(); \
		} \
	})


#define test_assert_msg( condition, msg ) \
	test_assert_fmt(condition, @"%@", msg)


#define test_assert( condition ) \
	test_assert_msg(condition, @#condition)


#define test_assert_error( error, _domain, _code ) \
	({ \
		test_assert(error); \
		if ( error.code != _code || ![error.domain isEqual:_domain]) { \
			fprintf(stderr, "%s:%d: %s:%ld != %s:%ld\n", \
				__FUNCTION__, __LINE__, \
				error.domain.UTF8String, (long)error.code, \
				_domain.UTF8String, (long)_code \
			); \
		} \
	})


// ----------------------------------------------------------------------------

__attribute__((objc_subclassing_restricted))
@interface TestAssert : NSObject

	+ (instancetype)new __attribute__((unavailable));

	- (instancetype)init __attribute__((unavailable));

@end


// ============================================================================
_Pragma("clang assume_nonnull end")
