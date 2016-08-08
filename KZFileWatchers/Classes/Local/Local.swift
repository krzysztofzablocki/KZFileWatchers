//
//  Local.swift
//  KZFileWatchers
//
//  Created by Krzysztof Zabłocki on 05/08/16.
//
//

import Foundation

public extension FileWatcher {
    
    /**
     Watcher for local files, it uses content diffing.
     */
    public final class Local: FileWatcherProtocol {
        private typealias CancelBlock = () -> Void
        
        private enum State {
            case Started(source: dispatch_source_t, fileHandle: CInt, callback: FileWatcher.UpdateClosure, cancel: CancelBlock)
            case Stopped
        }
        
        private let path: String
        private let refreshInterval: NSTimeInterval
        private let queue: dispatch_queue_t
        
        private var state: State = .Stopped
        private var isProcessing: Bool = false
        private var cancelReload: CancelBlock?
        private var previousContent: NSData?
        
        /**
         Initializes watcher to specified path.
         
         - parameter path:     Path of file to observe.
         - parameter refreshInterval: Refresh interval to use for updates.
         - parameter queue:    Queue to use for firing data processing and `onChange` callback.
         
         - note: By default it throttles to 60 FPS, some editors can generate stupid multiple saves that mess with file system e.g. Sublime with AutoSave plugin is a mess and generates different file sizes, this will limit wasted time trying to load faster than 60 FPS, and no one should even notice it's throttled
         */
        public init(path: String, refreshInterval: NSTimeInterval = 1/60, queue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.path = path
            self.refreshInterval = refreshInterval
            self.queue = queue
        }
        
        /**
         Starts observing file changes.
         
         - throws: FileWatcher.Error
         */
        public func start(closure: FileWatcher.UpdateClosure) throws {
            guard case .Stopped = state else { throw Error.alreadyStarted }
            try startObserving(closure)
        }
        
        /**
         Stops observing file changes.
         */
        public func stop() throws {
            guard case let .Started(_, _, _, cancel) = state else { throw Error.alreadyStopped }
            cancelReload?()
            cancelReload = nil
            cancel()
            
            state = .Stopped
        }
        
        private func startObserving(closure: FileWatcher.UpdateClosure) throws {
            let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            let handle = open(path, O_EVTONLY)
            
            if handle == -1 {
                throw Error.failedToStart(reason: "Failed to open file")
            }
            
            let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                UInt(handle),
                                                UInt(DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE),
                                                queue)
            
            let cancelBlock = {
                dispatch_source_cancel(source)
            }
            
            dispatch_source_set_event_handler(source) {
                let flags = dispatch_source_get_data(source)
                if flags & DISPATCH_VNODE_DELETE == DISPATCH_VNODE_DELETE {
                    _ = try? self.stop()
                    _ = try? self.startObserving(closure)
                    return
                }
                
                self.needsToReload()
            }
            
            dispatch_source_set_cancel_handler(source) {
                close(handle)
            }
            
            dispatch_resume(source)
            
            state = .Started(source: source, fileHandle: handle, callback: closure, cancel: cancelBlock)
            refresh()
        }
        
        private func needsToReload() {
            guard case .Started = state else { return }
            
            cancelReload?()
            cancelReload = throttle(after: refreshInterval) { self.refresh() }
        }
        
        /**
         Force refresh, can only be used if the watcher was started and it's not processing.
        */
        public func refresh() {
            guard case let .Started(_, _, closure, _) = state where isProcessing == false else { return }
            isProcessing = true
            
            guard let content = try? NSData(contentsOfFile: path, options: .DataReadingUncached) else {
                isProcessing = false
                return
            }
            
            if content != previousContent {
                previousContent = content
                closure(.updated(data: content))
            } else {
                closure(.noChanges)
            }
            
            isProcessing = false
            cancelReload = nil
        }
        
        private func throttle(after after: Double, action: () -> Void) -> CancelBlock {
            var isCancelled = false
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(after * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                if !isCancelled {
                    action()
                }
            }
            
            return {
                isCancelled = true
            }
        }
    }
    
}


public extension FileWatcher.Local {
    #if (arch(i386) || arch(x86_64)) && os(iOS)
    
    /**
     Returns username of OSX machine when running on simulator.
     
     - returns: Username (if available)
     */
    public class func simulatorOwnerUsername() -> String {
        //! running on simulator so just grab the name from home dir /Users/{username}/Library...
        let usernameComponents = NSHomeDirectory().componentsSeparatedByString("/")
        guard usernameComponents.count > 2 else { fatalError() }
        return usernameComponents[2]
    }
    #endif
}
