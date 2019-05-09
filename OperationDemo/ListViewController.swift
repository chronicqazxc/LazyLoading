//
//  ListViewController.swift
//  OperationDemo
//
//  Created by Hsiao, Wayne on 2019/4/23.
//  Copyright © 2019 Hsiao, Wayne. All rights reserved.
//

import UIKit

class ListViewController: UITableViewController {
    var pendingOperations = PendingIconDownloaderOperations()
    var appContainer: AppContainer? {
        didSet {
            let apps = appContainer?.apps.map {
                AppIconDownloader($0)
            }
            pendingOperations = PendingIconDownloaderOperations(downloaders: apps ?? [AppIconDownloader]())
        }
    }

    let dataSourceURL = URL(string: "http://phobos.apple.com/WebObjects/MZStoreServices.woa/ws/RSS/toppaidapplications/limit=75/json")

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cellId")
        fetchPhotoDetails()
    }
    
    func fetchPhotoDetails() {
        let request = URLRequest(url: dataSourceURL!)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let task = URLSession(configuration: .default).dataTask(with: request) { (data, response, error) in
            let alertController = UIAlertController(title: "Oops!",
                                                    message: "There was an error fetching photo details",
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default)
            alertController.addAction(okAction)
            
            if let data = data {
                do {
                    if let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        self.appContainer = AppContainer.initWith(dic)
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        self.tableView.reloadData()
                    }
                } catch {
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            
            if error != nil {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        task.resume()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pendingOperations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellId")
        if cell?.accessoryView == nil {
            let indicator = UIActivityIndicatorView(style: .gray)
            cell?.accessoryView = indicator
        }
        let indicator = cell?.accessoryView as! UIActivityIndicatorView
        let appIconDownloader = pendingOperations[indexPath.row]
        cell?.textLabel?.text = appIconDownloader.app.title
        cell?.imageView?.image = appIconDownloader.image
        
        switch appIconDownloader.iconDownloadStatus {
        case .failed:
            indicator.stopAnimating()
            cell?.textLabel?.text = "Failed to load"
        case .downloaded:
            indicator.stopAnimating()
        case .new:
            indicator.startAnimating()
            if !tableView.isDragging && !tableView.isDecelerating {
                startOperations(for: appIconDownloader, at: indexPath)
            }
        }
        return cell!
    }
    
    func startOperations(for appIconDownloader: AppIconDownloader, at indexPath: IndexPath) {
        pendingOperations.startDownload(for: appIconDownloader, at: indexPath) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if $0 == .finished {
                DispatchQueue.main.async {
                    strongSelf.tableView.reloadRows(at: [indexPath], with: .fade)
                }
            }
        }
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pendingOperations.suspendAllOperations()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadImagesForOnScreenCells()
            pendingOperations.resumeAllOperations()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadImagesForOnScreenCells()
        pendingOperations.resumeAllOperations()
    }
    
    func loadImagesForOnScreenCells() {
        if let pathArray = tableView.indexPathsForVisibleRows {
            var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
            allPendingOperations.formUnion(pendingOperations.downloadsInProgress.keys)
            
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathArray)
            toBeCancelled.subtract(visiblePaths)
            
            var toBeStart = visiblePaths
            toBeStart.subtract(allPendingOperations)
            
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
            }
            
            for indexPath in toBeStart {
                let appIconDownloader = pendingOperations[indexPath.row]
                startOperations(for: appIconDownloader, at: indexPath)
            }
        }
    }
}
