//
//  Remote.swift
//  KZFileWatchers
//
//  Created by Krzysztof Zabłocki on 05/08/16.
//
//
import Foundation

public extension FileWatcher {
    
    /**
     Watcher for remote files, it supports both ETag and Last-Modified HTTP header tags.
     */
    public final class Remote: FileWatcherProtocol {
        private enum State {
            case started(sessionHandler: URLSessionHandler, timer: NSTimer)
            case stopped
        }
        
        private struct Constants {
            static let IfModifiedSinceKey = "If-Modified-Since"
            static let LastModifiedKey = "Last-Modified"
            static let IfNoneMatchKey = "If-None-Match"
            static let ETagKey = "Etag"
        }
        
        internal static var sessionConfiguration: NSURLSessionConfiguration = {
            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
            config.requestCachePolicy = .ReloadIgnoringLocalAndRemoteCacheData
            return config
        }()
        
        
        /// URL that this watcher is observing.
        let url: NSURL
        
        /// The minimal amount of time between querying the `url` again.
        let refreshInterval: NSTimeInterval
        
        private var state: State = .stopped
        
        /**
         Creates a new watcher using given URL and refreshInterval.
         
         - parameter url:             URL to observe.
         - parameter refreshInterval: Minimal refresh interval between queries.
         */
        public init(url: NSURL, refreshInterval: NSTimeInterval = 1) {
            self.url = url
            self.refreshInterval = refreshInterval
        }
        
        deinit {
            _ = try? stop()
        }
        
        public func start(closure: FileWatcher.UpdateClosure) throws {
            guard case .stopped = state else {
                throw FileWatcher.Error.alreadyStarted
            }
            
            let timer = NSTimer.scheduledTimerWithTimeInterval(refreshInterval, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
            state = .started(sessionHandler: URLSessionHandler(url: url, sessionConfiguration: FileWatcher.Remote.sessionConfiguration, callback: closure), timer: timer)
            
            timer.fire()
        }
        
        public func stop() throws {
            guard case let .started(_, timer) = state else { return }
            timer.invalidate()
            state = .stopped
        }
        
        /**
         Force refresh, can only be used if the watcher was started.
         
         - throws: `FileWatcher.Error.notStarted`
         */
        @objc public func refresh() throws {
            guard case let .started(handler, _) = state else { throw Error.notStarted }
            handler.refresh()
        }
    }
}

extension FileWatcher.Remote {
    
    private final class URLSessionHandler: NSObject, NSURLSessionDelegate, NSURLSessionDownloadDelegate {
        private var task: NSURLSessionDownloadTask? = nil
        private var lastModified: String = ""
        private var lastETag: String = ""
        
        private let callback: FileWatcher.UpdateClosure
        private let url: NSURL
        private lazy var session: NSURLSession = {
            return NSURLSession(configuration: self.sessionConfiguration, delegate: self, delegateQueue: self.processingQueue)
        }()
        
        private let processingQueue: NSOperationQueue = {
            let queue = NSOperationQueue()
            queue.maxConcurrentOperationCount = 1
            return queue
        }()
        
        private let sessionConfiguration: NSURLSessionConfiguration
        
        init(url: NSURL, sessionConfiguration: NSURLSessionConfiguration, callback: FileWatcher.UpdateClosure) {
            self.url = url
            self.sessionConfiguration = sessionConfiguration
            self.callback = callback
            super.init()
        }
        
        deinit {
            processingQueue.cancelAllOperations()
        }
        
        func refresh() {
            processingQueue.addOperationWithBlock { [weak self] in
                guard let strongSelf = self else { return }
                
                let request = NSMutableURLRequest(URL: strongSelf.url)
                request.setValue(strongSelf.lastModified, forHTTPHeaderField: Constants.IfModifiedSinceKey)
                request.setValue(strongSelf.lastETag, forHTTPHeaderField: Constants.IfNoneMatchKey)
            
                strongSelf.task = strongSelf.session.downloadTaskWithRequest(request)
                strongSelf.task?.resume()
            }
        }
        
        @objc func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
            guard let response = downloadTask.response as? NSHTTPURLResponse else {
                assertionFailure("expected NSHTTPURLResponse received \(downloadTask.response)")
                task = nil
                return
            }
            
            if response.statusCode == 304 {
                callback(.noChanges)
                task = nil
                return
            }
            
            if let modified = response.allHeaderFields[Constants.LastModifiedKey] as? String {
                lastModified = modified
            }
            
            if let etag = response.allHeaderFields[Constants.ETagKey] as? String {
                lastETag = etag
            }
            
            guard let data = NSData(contentsOfURL: location) else {
                assertionFailure("can't load data from URL \(location)")
                return
            }
            
            callback(.updated(data: data))
            task = nil
        }
    }
}
