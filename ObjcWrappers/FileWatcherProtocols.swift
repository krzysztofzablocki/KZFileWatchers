//
//  FileWatcherProtocols.swift
//  KZFileWatchers
//
//  Created by Andrey Morozov on 18/12/2018.
//

import Foundation

/**
Protocol for essence, that responsible for file refresh processing.
*/
@objc(FileWatcherDelegate)
public protocol FileWatcherOutput: NSObjectProtocol {
	
	/// Fires, when monitoring file is updated.
	///
	/// - Parameters:
	///	  - fileWatcher: The file watcher, which handles file refreshing.
	///   - type: Status of refresh result.
	///   - data: Content from file.
	func refreshDidOccur(from fileWatcher: FileWatcherInput, type: RefreshResultType, data: Data?)
}

/**
Protocol for File Watchers.
*/
@objc(FileWatcherProtocol)
public protocol FileWatcherInput: NSObjectProtocol {
	
	/// Responsible for file refresh processing.
	var delegate: FileWatcherOutput? { get set }
	
	/**
	Starts observing file changes, a file watcher can only have one callback.
	*/
	@objc(startWithError:)
	func start() throws
	
	/**
	Stops observing file changes.
	*/
	@objc(stopWithError:)
	func stop() throws
}
