import XCTest

class SentryANRTrackingIntegrationTests: XCTestCase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryANRTrackingIntegrationTests")
    
    private class Fixture {
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashAdapter
        let currentDate = TestCurrentDateProvider()
        let fileManager: SentryFileManager
        
        init() {
            options = Options()
            options.dsn = SentryANRTrackingIntegrationTests.dsn
    
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashAdapter.sharedInstance()
            
            let hub = SentryHub(client: client, andScope: nil, andCrashAdapter: crashWrapper, andCurrentDateProvider: currentDate)
            SentrySDK.setCurrentHub(hub)
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryANRTrackingIntegration!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        fixture.fileManager.store(TestData.appState)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.uninstall()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
    }

    func testWhenUnitTests_TrackerNotInitialized() {
        sut = SentryANRTrackingIntegration()
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testWhenNoUnitTests_TrackerInitialized() {
        givenInitializedTracker()
        
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testTestConfigurationFilePath() {
        sut = SentryANRTrackingIntegration()
        let path = Dynamic(sut).testConfigurationFilePath.asString
        XCTAssertEqual(path, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    }
    
    func test_ANRDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableANRTracking = false
        
        sut = SentryANRTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("ANRTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
    
    func testANRDetected_UpdatesAppStateToTrue() {
        givenInitializedTracker()
        
        Dynamic(sut).anrDetected()
        
        guard let appState = fixture.fileManager.readAppState() else {
            XCTFail("appState must not be nil")
            return
        }
        XCTAssertTrue(appState.isANROngoing)
    }
    
    func testANRStopped_UpdatesAppStateToFalse() {
        givenInitializedTracker()
        
        Dynamic(sut).anrStopped()
        
        guard let appState = fixture.fileManager.readAppState() else {
            XCTFail("appState must not be nil")
            return
        }
        XCTAssertFalse(appState.isANROngoing)
    }

    private func givenInitializedTracker() {
        sut = SentryANRTrackingIntegration()
        let options = Options()
        options.enableANRTrackingInDebug = true
        Dynamic(sut).setTestConfigurationFilePath(nil)
        sut.install(with: options)
    }
}