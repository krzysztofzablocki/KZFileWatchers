//
//  ViewController.swift
//  KZFileWatchers
//
//  Created by Krzysztof Zabłocki on 08/08/2016.
//  Copyright (c) 2016 Krzysztof Zabłocki. All rights reserved.
//

import UIKit
import KZFileWatchers

class ViewController: UIViewController {
    @IBOutlet private weak var textLabel: UILabel!
    private var fileWatcher: FileWatcherProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesktopDaemon()
    }

    /**
     Starts a file daemon observing the the file with name `filename` on desktop directory, it will automatically create the file with current specification if it doesn't exist.

     - parameter filename: Name of the file on the user desktop folder. defaults to `traits.json`
     */
    func setupDesktopDaemon(filename: String = "KZFileWatchers-Hello.txt") {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
                let path = "/Users/\(FileWatcher.Local.simulatorOwnerUsername())/Desktop/\(filename)"
                if !NSFileManager.defaultManager().fileExistsAtPath(path) {
                    "Hello daemon world!".dataUsingEncoding(NSUTF8StringEncoding)?.writeToFile(path, atomically: true)
                }

                fileWatcher = FileWatcher.Local(path: path)
                try! fileWatcher?.start({ result in
                    switch result {
                    case .noChanges:
                        break
                    case .updated(let data):
                        let text = String(data: data, encoding: NSUTF8StringEncoding)
                        self.textLabel.text = text
                    }
                })

        #endif
    }
}

