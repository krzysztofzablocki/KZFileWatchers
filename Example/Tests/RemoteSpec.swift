import Quick
import Nimble
import OHHTTPStubs

@testable import KZFileWatchers

private struct Constants {
    static let IfModifiedSinceKey = "If-Modified-Since"
    static let LastModifiedKey = "Last-Modified"
    static let IfNoneMatchKey = "If-None-Match"
    static let ETagKey = "Etag"
}

class RemoteSpec: QuickSpec {
    override func spec() {
        describe("FileWatcher.Remote") {
            typealias RemoteFileWatcher = FileWatcher.Remote

            let fakeURL = NSURL(string: "myfakeurl.com/file.json")!

            var stubbedReplay: OHHTTPStubsResponse?

            var sut: RemoteFileWatcher?
            var recordedRequest: NSURLRequest?

            beforeEach {
                OHHTTPStubs.setEnabled(true, forSessionConfiguration: RemoteFileWatcher.sessionConfiguration)

                stub({ (request) -> Bool in
                    recordedRequest = request
                    return true
                    }, response: { _ in
                        return stubbedReplay ?? OHHTTPStubsResponse(data: "initial".dataUsingEncoding(NSUTF8StringEncoding)!, statusCode: 200, headers: nil)
                })

                sut = RemoteFileWatcher(url: fakeURL, refreshInterval: 100.0)
            }

            afterEach {
                sut = nil
                OHHTTPStubs.removeAllStubs()
                recordedRequest = nil
                stubbedReplay = nil
            }

            describe("refreshing logic") {
                it("notifies once on start") {
                    let sut = RemoteFileWatcher(url: fakeURL, refreshInterval: 100.0)
                    var counter = 0

                    guard let _ = try? sut.start({ _ in
                        counter += 1
                    }) else { return fail() }

                    expect(counter).toEventually(equal(1))
                }

                it("notifies further on refresh") {
                    let sut = RemoteFileWatcher(url: fakeURL, refreshInterval: 100.0)
                    var counter = 0

                    guard let _ = try? sut.start({ _ in
                        counter += 1
                    }) else { return fail() }
                    try! sut.refresh()

                    expect(counter).toEventually(equal(2))
                }

            }

            describe("when setting up requests") {

                beforeEach {
                    guard let _ = try? sut?.start({ _ in

                        stubbedReplay = OHHTTPStubsResponse(data: "initial".dataUsingEncoding(NSUTF8StringEncoding)!, statusCode: 200, headers: [Constants.LastModifiedKey: "testLastModified", Constants.ETagKey: "testEtag"])

                        guard let _ = try? sut?.refresh() else { return fail() }

                    }) else { return fail() }
                }

                context("given the initial response contains Last-Modified") {
                    it("sets it as If-Modified-Since") {
                        expect(recordedRequest?.allHTTPHeaderFields?[Constants.IfModifiedSinceKey]).toEventually(equal("testLastModified"))
                    }
                }

                context("given the initial response contains ETag") {
                    it("sets it as If-None-Match") {
                        expect(recordedRequest?.allHTTPHeaderFields?[Constants.IfNoneMatchKey]).toEventually(equal("testEtag"))
                    }
                }
            }

            context("given it already started") {
                var receivedData: NSData?
                var receivedNoChanges: Bool?

                beforeEach {
                    guard let _ = try? sut?.start({ result in
                        switch result {
                        case .noChanges:
                            receivedNoChanges = true
                        case let .updated(data):
                            receivedData = data
                        }
                    }) else { return fail() }
                }

                afterEach {
                    _ = try? sut?.stop()
                    receivedData = nil
                    receivedNoChanges = nil
                }

                it("throws error on subsequent start") {
                    expect { try sut?.start { _ in } }.to(throwError(FileWatcher.Error.alreadyStarted))
                }

                it("receives data") {
                    expect(receivedData).toEventuallyNot(beNil())
                }


                it("receives noChanges on 304 status code") {
                    stubbedReplay = {
                        let response = OHHTTPStubsResponse()
                        response.statusCode = 304
                        return response
                    }()

                    expect(receivedNoChanges).toEventually(beTrue())
                }

                context("given it's stopped") {
                    beforeEach {
                        guard let _ = try? sut?.stop() else { return fail() }
                    }

                    it("throws error on refresh") {
                        expect{ try sut?.refresh() }.to(throwError(FileWatcher.Error.notStarted))
                    }
                }

                context("given it received initial data") {
                    beforeEach {
                        receivedData = nil
                        receivedNoChanges = nil

                        guard let _ = try? sut?.refresh() else { return fail() }
                    }

                    it("doesn't receive data if file didn't change") {
                        expect(receivedData).toEventually(beNil())
                    }

                    it("receives noChanges if file didn't change") {
                        expect(receivedNoChanges).toEventually(beNil())
                    }
                }
            }
        }
    }
}
