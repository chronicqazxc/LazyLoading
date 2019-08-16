//
//  TopPaids.swift
//  OperationDemo
//
//  Created by Hsiao, Wayne on 2019/5/9.
//  Copyright © 2019 Hsiao, Wayne. All rights reserved.
//

import UIKit

struct App {
    let image: String
    let title: String
    let link: String
}

struct AppContainer {
    let apps: [App]
    static func initWith(_ dic: [String: Any]) -> AppContainer? {
        guard let feed = dic["feed"] as? [String: Any],
            let entry = feed["results"] as? [[String: Any]] else {
            return nil
        }
        let apps = entry.map { (entry) -> App in
            guard let imageURL = entry["artworkUrl100"] as? String,
                let title = entry["name"] as? String,
                let link = entry["url"] as? String else {
                return App(image: "", title: "", link: "")
            }
            return App(image: imageURL, title: title, link: link)
        }
        let container = AppContainer(apps: apps)
        return container
    }
}
