//
//  AppOperations.swift
//  OperationDemo
//
//  Created by Hsiao, Wayne on 2019/5/9.
//  Copyright © 2019 Hsiao, Wayne. All rights reserved.
//

import UIKit

enum AppIconDownloadStatus {
    case new, downloaded, failed
}
enum OperationStatus {
    case cancel, finished
}

class AppIconDownloader: Operation {
    var app: App
    var iconDownloadStatus = AppIconDownloadStatus.new
    var image: UIImage? {
        didSet {
            assert(image != nil, "image should not be nil")
        }
    }
    
    init(_ app: App) {
        self.app = app
    }
    
    /// https://developer.apple.com/documentation/foundation/operation/1413540-isfinished
//    override var isFinished: Bool {
//        if image == nil {
//            return false
//        } else {
//            return true
//        }
//    }
    
    override func main() {
        if isCancelled {
            assert(image != nil, "image should not be nil.")
            return
        }
        
        guard let url = URL(string: app.image),
            let imageData = try? Data(contentsOf: url) else {
            assert(image != nil, "image should not be nil.")
            return
        }
        
        if isCancelled {
            return
        }
        
        if !imageData.isEmpty {
            image = UIImage(data: imageData)
            assert(image != nil, "image should not be nil.")
            iconDownloadStatus = .downloaded
        } else {
            image = UIImage(named: "Failed")
            iconDownloadStatus = .failed
        }
    }
}

class PendingIconDownloaderOperations {
    /// Data Source
    fileprivate var appIconDownloaders = [AppIconDownloader]()
    typealias Key = AnyHashable
    /// Control respective AppIconDownloaders
    fileprivate var downloadsInProgress = [Key: AppIconDownloader]()
    fileprivate lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Image Filtration queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    var count: Int {
        return appIconDownloaders.count
    }
    
    subscript (index: Int) -> AppIconDownloader {
        get {
            let downloader = appIconDownloaders[index]
            if downloader.isCancelled == true {
                let newDownloader = AppIconDownloader(downloader.app)
                appIconDownloaders[index] = newDownloader
            }
            return appIconDownloaders[index]
        }
        set {
            appIconDownloaders[index] = newValue
        }
    }
    
    func startDownload(for appIconDownloader: AppIconDownloader,
                       at key: Key,
                       completeHandler: @escaping (OperationStatus)->Void) {
        guard appIconDownloader.iconDownloadStatus == .new else {
            return
        }
        
        guard downloadsInProgress[key] == nil else {
            return
        }
        appIconDownloader.completionBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if appIconDownloader.isCancelled {
                completeHandler(.cancel)
            }
            DispatchQueue.main.async {
                if appIconDownloader.isFinished && !appIconDownloader.isCancelled {
                    assert(appIconDownloader.image != nil, "image should not be nil")
                }
                strongSelf.downloadsInProgress.removeValue(forKey: key)
                completeHandler(.finished)
            }
        }
        if !downloadQueue.operations.contains(appIconDownloader) {
            downloadQueue.addOperation(appIconDownloader)
        }
        downloadsInProgress[key] = appIconDownloader
    }
    
    func cancel(at keys: [Key]) {
        for key in keys {
            if let pendingDownload = downloadsInProgress[key] {
                pendingDownload.cancel()
                downloadsInProgress.removeValue(forKey: key)
            }
        }
    }
    
    func suspendAllOperations() {
        downloadQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        downloadQueue.isSuspended = false
    }

    func loadImagesForOnScreenCells(indexPathsForVisibleRows pathes: [IndexPath],
                                    completeHander: @escaping ([IndexPath])->Void) {

        guard let allPendingOperations = Set(downloadsInProgress.keys) as? Set<IndexPath> else {
            return
        }
        //            allPendingOperations.formUnion(allPendingOperations)

        var toBeCancelled = allPendingOperations
        let visiblePaths = Set(pathes)
        toBeCancelled.subtract(visiblePaths)

        var toBeStart = visiblePaths
        toBeStart.subtract(allPendingOperations)

        cancel(at: Array(toBeCancelled))

        for indexPath in toBeStart {
            let appIconDownloader = self[indexPath.row]
            startDownload(for: appIconDownloader, at: indexPath) {
                if $0 == .finished {
                    DispatchQueue.main.async {
                        completeHander([indexPath])
                    }
                }
            }
        }
    }
}

extension PendingIconDownloaderOperations {
    convenience init(downloaders: [AppIconDownloader]) {
        self.init()
        self.appIconDownloaders = downloaders
    }
}
