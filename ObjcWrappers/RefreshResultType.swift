//
//  RefreshResultType.swift
//  KZFileWatchers
//
//  Created by Andrey Morozov on 18/12/2018.
//

import Foundation

/**
Enum that contains status of refresh result.
*/
@objc(RefreshResult)
public enum RefreshResultType: Int {
	/**
	Watched file didn't change since last update.
	*/
	case noChanges
	
	/**
	Watched file did change.
	*/
	case updated
}
