#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryCrashAdapter.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryCrashAdapter.h>
#import <SentryDependencyContainer.h>
#import <SentryOptions+Private.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nullable, nonatomic, copy) NSString *testConfigurationFilePath;

@end

@implementation SentryANRTrackingIntegration

- (instancetype)init
{
    if (self = [super init]) {
        self.testConfigurationFilePath
            = NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"];
    }
    return self;
}

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.appStateManager = dependencies.appStateManager;

    self.tracker =
        [[SentryANRTracker alloc] initWithDelegate:self
                             timeoutIntervalMillis:options.anrTimeoutIntervalMillis
                               currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                                      crashAdapter:dependencies.crashAdapter
                              dispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                                     threadWrapper:dependencies.threadWrapper];
    [self.tracker start];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableANRTracking) {
        return YES;
    }

    SentryCrashAdapter *crashAdapter = [SentryCrashAdapter sharedInstance];
    if ([crashAdapter isBeingTraced] && !options.enableANRTrackingInDebug) {
        return YES;
    }

    // The testConfigurationFilePath is not nil when running unit tests. This doesn't work for UI
    // tests though.
    if (self.testConfigurationFilePath) {
        [SentryLog logWithMessage:@"Won't track ANRs, because detected that unit tests are running."
                         andLevel:kSentryLevelDebug];
        return YES;
    }

#if SENTRY_HAS_UIKIT
    return NO;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentryANRTrackingIntegration will not track ANRs, "
                              @"because we only track them to avoid false positives OOMs."
                     andLevel:kSentryLevelInfo];
    return YES;
#endif
}

- (void)uninstall
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

- (void)anrDetected
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = YES; }];
#endif
}

- (void)anrStopped
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager
        updateAppState:^(SentryAppState *appState) { appState.isANROngoing = NO; }];
#endif
}

@end

NS_ASSUME_NONNULL_END
