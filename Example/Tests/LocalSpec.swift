import Quick
import Nimble

@testable import KZFileWatchers

class LocalSpec: QuickSpec {
    override func spec() {
        describe("FileWatcher.Local") {
            typealias LocalFileWatcher = FileWatcher.Local
            
            let dirPath = NSTemporaryDirectory()
            let path = dirPath.stringByAppendingString("test.txt")
            
            var sut: LocalFileWatcher?
            
            beforeEach {
                guard NSFileManager.defaultManager().createFileAtPath(path, contents: "initial".dataUsingEncoding(NSUTF8StringEncoding), attributes: nil) else { return fail() }
                sut = LocalFileWatcher(path: path, refreshInterval: 10)
            }
            
            afterEach {
                sut = nil
            }
            
            describe("refreshing logic") {
                it("notifies once on start") {
                    let sut = LocalFileWatcher(path: path)
                    var counter = 0
                    
                    guard let _ = try? sut.start({ _ in
                        counter += 1
                    }) else { return fail() }
                    
                    expect(counter).toEventually(equal(1))
                }
                
                it("notifies further on refresh") {
                    let sut = LocalFileWatcher(path: path)
                    var counter = 0
                    
                    guard let _ = try? sut.start({ _ in
                        counter += 1
                    }) else { return fail() }
                    sut.refresh()
                    
                    expect(counter).toEventually(equal(2))
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
                
                it("receives noChanges on non modified data") {
                    sut?.refresh()
                    
                    expect(receivedNoChanges).toEventually(beTrue())
                }
                
                context("given it's stopped") {
                    beforeEach {
                        guard let _ = try? sut?.stop() else { return fail() }
                    }
                    
                    it("throws error on stop") {
                        expect{ try sut?.stop() }.to(throwError(FileWatcher.Error.alreadyStopped))
                    }
                }
                
                context("given it received initial data") {
                    beforeEach {
                        receivedData = nil
                        receivedNoChanges = nil
                        
                        sut?.refresh()
                    }

                    it("doesn't receive data if file didn't change") {
                        expect(receivedData).toEventually(beNil())
                    }
                    
                    it("receives noChanges on non modified data") {
                        expect(receivedNoChanges).toEventually(beTrue())
                    }

                    it("receives new data on file change") {
                        guard let expectedData = "changed".dataUsingEncoding(NSUTF8StringEncoding) else { return fail() }
                        expectedData.writeToFile(path, atomically: true)
                        
                        sut?.refresh()
                        
                        expect(receivedData).toEventually(equal(expectedData))
                    }
                }
            }
        }
    }
}
