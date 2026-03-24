// ABOUTME: Tests for browser web view caching in TerminalSurfaceCache.
// ABOUTME: Verifies cached WKWebView instances are reused across tab switches.

@testable import FactoryFloor
import WebKit
import XCTest

@MainActor
final class BrowserViewTests: XCTestCase {
    func testWebViewCacheReturnsSameInstance() {
        let cache = TerminalSurfaceCache()
        let id = UUID()

        let first = cache.webView(for: id)
        let second = cache.webView(for: id)

        XCTAssertTrue(first === second, "Cache should return the same WKWebView instance")
    }

    func testWebViewCacheReturnsDifferentInstancesForDifferentIDs() {
        let cache = TerminalSurfaceCache()
        let id1 = UUID()
        let id2 = UUID()

        let view1 = cache.webView(for: id1)
        let view2 = cache.webView(for: id2)

        XCTAssertFalse(view1 === view2, "Different IDs should get different WKWebView instances")
    }

    func testRemoveWebViewClearsCache() {
        let cache = TerminalSurfaceCache()
        let id = UUID()

        let first = cache.webView(for: id)
        cache.removeWebView(for: id)
        let second = cache.webView(for: id)

        XCTAssertFalse(first === second, "After removal, a new WKWebView instance should be created")
    }

    func testCoordinatorConformsToWKUIDelegate() {
        let webView = WKWebView()
        let representable = WebViewRepresentable(
            webView: webView,
            isLoading: .constant(false),
            canGoBack: .constant(false),
            canGoForward: .constant(false),
            urlText: .constant(""),
            connectionError: .constant(false),
            pageTitle: .constant(nil)
        )
        let coordinator = representable.makeCoordinator()
        XCTAssertTrue(coordinator is WKUIDelegate, "Coordinator should conform to WKUIDelegate")
    }
}
