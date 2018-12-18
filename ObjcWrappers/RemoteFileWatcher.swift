//
//  RemoteFileWatcher.swift
//  KZFileWatchers
//
//  Created by Andrey Morozov on 18/12/2018.
//

import Foundation

/**
Watcher for remote files, it supports both ETag and Last-Modified HTTP header tags.
*/
@objc
public final class RemoteFileWatcher: NSObject {
	
	/// Original remote FileWatcher, that does all work.
	private let remoteWatcher: FileWatcher.Remote
	
	public var delegate: FileWatcherOutput?
	
	/**
	Creates a new watcher using given URL and refreshInterval.
	
	- parameter url:             URL to observe.
	
	- note: By default, it uses refreshInterval equal to 1.
	*/
	@objc
	public convenience init(url: URL) {
		self.init(url: url, refreshInterval: 1)
	}
	
	/**
	Creates a new watcher using given URL and refreshInterval.
	
	- parameter url:             URL to observe.
	- parameter refreshInterval: Minimal refresh interval between queries.
	*/
	@objc
	public init(url: URL, refreshInterval: TimeInterval) {
		remoteWatcher = FileWatcher.Remote(url: url, refreshInterval: refreshInterval)
	}
	
	@objc
	public func refresh() throws {
		try remoteWatcher.refresh()
	}
}

extension RemoteFileWatcher: FileWatcherInput {
	
	public func start() throws {
		try remoteWatcher.start { (result) in
			switch result {
			case .noChanges:
				self.delegate?.refreshDidOccur(type: .noChanges, data: nil)
			case .updated(let data):
				self.delegate?.refreshDidOccur(type: .updated, data: data)
			}
		}
	}
	
	public func stop() throws {
		try remoteWatcher.stop()
	}
}
