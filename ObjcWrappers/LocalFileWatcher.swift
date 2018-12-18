//
//  LocalFileWatcher.swift
//  KZFileWatchers
//
//  Created by Andrey Morozov on 18/12/2018.
//

import Foundation

/**
Watcher for local files, it uses content diffing.
*/
@objc
public final class LocalFileWatcher: NSObject {
	
	/// Original local FileWatcher, that does all work.
	private let localWatcher: FileWatcher.Local
	
	public var delegate: FileWatcherOutput?
	
	/**
	Initializes watcher to specified path.
	
	- parameter path:     Path of file to observe.
	
	- note: By default it throttles to 60 FPS, some editors can generate stupid multiple saves that mess with file system e.g. Sublime with AutoSave plugin is a mess and generates different file sizes, this will limit wasted time trying to load faster than 60 FPS, and no one should even notice it's throttled.
	*/
	@objc
	public convenience init(path: String) {
		self.init(path: path, refreshInterval: 1/60, queue: DispatchQueue.main)
	}
	
	/**
	Initializes watcher to specified path.
	
	- parameter path:     Path of file to observe.
	- parameter refreshInterval: Refresh interval to use for updates.
	- parameter queue:    Queue to use for firing `onChange` callback.
	*/
	@objc
	public init(path: String, refreshInterval: TimeInterval, queue: DispatchQueue) {
		localWatcher = FileWatcher.Local(path: path, refreshInterval: refreshInterval, queue: queue)
	}
	
	@objc
	public func refresh() {
		localWatcher.refresh()
	}
}

extension LocalFileWatcher: FileWatcherInput {
	
	public func start() throws {
		try localWatcher.start { (result) in
			switch result {
			case .noChanges:
				self.delegate?.refreshDidOccur(type: .noChanges, data: nil)
			case .updated(let data):
				self.delegate?.refreshDidOccur(type: .updated, data: data)
			}
		}
	}
	
	public func stop() throws {
		try localWatcher.stop()
	}
}
