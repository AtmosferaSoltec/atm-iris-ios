//
//  WebLinks.swift
//  iris
//

import Foundation

/// Places the app sends people to. Accounts, lyrics, music and media are managed on the web.
nonisolated enum WebLinks {
    static let app = URL(string: "https://iris.atmosferast.com") ?? URL(fileURLWithPath: "/")
}
