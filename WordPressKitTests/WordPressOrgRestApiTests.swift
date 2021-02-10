import Foundation
import XCTest
import OHHTTPStubs
@testable import WordPressKit

class WordPressOrgRestApiTests: XCTestCase {

    let apiBase = URL(string: "https://wordpress.org/wp-json/")!

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()
    }

    private func isAPIRequest() -> HTTPStubsTestBlock {
        return { request in
            return request.url?.absoluteString.hasPrefix(self.apiBase.absoluteString) ?? false
        }
    }

    func testUnauthorizedCall() {
        stub(condition: isAPIRequest()) { request in
            let stubPath = OHPathForFile("wp-forbidden.json", type(of: self))
            return fixture(filePath: stubPath!, status: 401, headers: ["Content-Type" as NSObject: "application/json" as AnyObject])
        }
        let expect = self.expectation(description: "One callback should be invoked")
        let api = WordPressOrgRestApi(apiBase: apiBase)
        api.GET("wp/v2/settings", parameters: nil) { (result, response) in
            expect.fulfill()
            switch result {
            case .success(_):
                XCTFail("This call should not suceed")
            case .failure(_):
                XCTAssertEqual(response?.statusCode, 401, "Response should be unauthorized")
            }
        }
        waitForExpectations(timeout: 2, handler: nil)
    }

    func testSuccessfulGetCall() {
        stub(condition: isAPIRequest()) { request in
            let stubPath = OHPathForFile("wp-pages.json", type(of: self))
            return fixture(filePath: stubPath!, headers: ["Content-Type" as NSObject: "application/json" as AnyObject])
        }
        let expect = self.expectation(description: "One callback should be invoked")
        let api = WordPressOrgRestApi(apiBase: apiBase)
        api.GET("wp/v2/pages", parameters: nil) { (result, response) in
            expect.fulfill()
            switch result {
            case .success(let object):
                guard let pages = object as? [AnyObject] else {
                    XCTFail("Unexpected API result")
                    return
                }
                XCTAssertEqual(pages.count, 10, "The API should return 10 pages")
            case .failure(_):
                XCTFail("This call should not fail")
            }
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSuccessfulPostCall() {
        stub(condition: isAPIRequest()) { request in
            let stubPath = OHPathForFile("wp-reusable-blocks.json", type(of: self))
            return fixture(filePath: stubPath!, headers: ["Content-Type" as NSObject: "application/json" as AnyObject])
        }
        let expect = self.expectation(description: "One callback should be invoked")
        let api = WordPressOrgRestApi(apiBase: apiBase)
        let blockContent = "<!-- wp:paragraph --><p>Some text</p><!-- /wp:paragraph --><!-- wp:list --><ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul><!-- /wp:list -->"
        let parameters: [String: String] = ["id": "6", "content": blockContent]
        api.POST("wp/v2/blocks/6", parameters: parameters as [String: AnyObject]) { (result, response) in
            expect.fulfill()
            switch result {
            case .success(let object):
                guard let block = object as? Dictionary<String, AnyObject> else {
                    XCTFail("Unexpected API result")
                    return
                }
                XCTAssertEqual(block.count, 15, "The API should return the block")
            case .failure(_):
                XCTFail("This call should not fail")
            }
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
}
