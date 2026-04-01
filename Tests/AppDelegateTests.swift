// ABOUTME: Tests for AppDelegate startup behaviors that interact with system callbacks.
// ABOUTME: Verifies notification authorization results are handled on the main thread.

@testable import FactoryFloor
import UserNotifications
import XCTest

final class AppDelegateTests: XCTestCase {
    func testNotificationAuthorizationResultIsHandledOnMainThread() {
        let handledOnMainThread = expectation(description: "notification authorization handled on main thread")

        AppDelegate.handleNotificationAuthorizationResult(granted: false, error: nil) { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            handledOnMainThread.fulfill()
        }

        wait(for: [handledOnMainThread], timeout: 1)
    }

    func testNotificationAuthorizationRequestHandlesBackgroundCallbackOnMainThread() {
        let handledOnMainThread = expectation(description: "background authorization callback handled on main thread")
        let center = NotificationCenterStub()

        AppDelegate.requestNotificationAuthorization(using: center) { _, _ in
            XCTAssertTrue(center.didRequestAuthorization)
            XCTAssertEqual(center.requestedOptions, [.alert, .sound])
            XCTAssertTrue(Thread.isMainThread)
            handledOnMainThread.fulfill()
        }

        wait(for: [handledOnMainThread], timeout: 1)
    }
}

private final class NotificationCenterStub: NotificationAuthorizationRequesting, @unchecked Sendable {
    private(set) var didRequestAuthorization = false
    private(set) var requestedOptions: UNAuthorizationOptions = []

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void
    ) {
        didRequestAuthorization = true
        requestedOptions = options

        DispatchQueue.global().async {
            completionHandler(false, nil)
        }
    }
}
