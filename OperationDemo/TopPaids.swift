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
            let entry = feed["entry"] as? [[String: Any]] else {
            return nil
        }
        let apps = entry.map { (entry) -> App in
            guard let images = entry["im:image"] as? [[String: Any]],
                let titleDic = entry["title"] as? [String: Any],
                let linkDic = entry["link"] as? [String: Any],
                let attributeDic = linkDic["attributes"] as? [String: Any] else {
                return App(image: "", title: "", link: "")
            }
            let imageURL = images.first?["label"] as? String ?? ""
            let title = titleDic["label"] as? String ?? ""
            let link = attributeDic["href"] as? String ?? ""
            return App(image: imageURL, title: title, link: link)
        }
        let container = AppContainer(apps: apps)
        return container
    }
}
