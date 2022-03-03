#pragma once

#import <Foundation/Foundation.h>
#include <string>

@interface SentryBacktrace : NSObject {
@public
    NSInteger priority;
    NSString *threadName;
    NSString *queueName;
    NSMutableArray<NSValue *> *addresses; // array of 64-bit pointer NSValues
}
@end

@interface SentryProfilingEntry : NSObject {
@public
    NSInteger tid;
    SentryBacktrace *backtrace;
    uint64_t elapsedRelativeToStartDateNs;
    uint64_t costNs;
}
@end

@interface SentryProfilingTraceLogger : NSObject {
@public
    NSInteger referenceUptimeNs;
}
@end