// ABOUTME: Tests for AppDelegate startup behaviors that interact with system callbacks.
// ABOUTME: Verifies notification authorization results are handled on the main thread.

@testable import FactoryFloor
import XCTest

final class AppDelegateTests: XCTestCase {
    func testNotificationAuthorizationResultIsHandledOnMainThread() {
        let handledOnMainThread = expectation(description: "notification authorization handled on main thread")

        DispatchQueue.global().async(group: nil, qos: .default, flags: []) {
            AppDelegate.handleNotificationAuthorizationResult(granted: false, error: nil) { _, _ in
                XCTAssertTrue(Thread.isMainThread)
                handledOnMainThread.fulfill()
            }
        }

        wait(for: [handledOnMainThread], timeout: 1)
    }
}
