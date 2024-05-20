#import "TestWatch.h"

#define var __auto_type
#define let const var

_Pragma("clang assume_nonnull begin")
// ============================================================================

__attribute__((objc_direct_members))
@implementation TestWatch
	{
		NSDate * _start;
	}


	- (void)start
	{
		_start = [NSDate date];
	}


	- (NSTimeInterval)stop
	{
		if (!_start) return 0;
		return [[NSDate date] timeIntervalSinceDate:_start];
	}

@end

// ============================================================================
_Pragma("clang assume_nonnull end")
