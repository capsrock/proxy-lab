//
//  ProxyLabApp.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

@main
struct ProxyLabApp: App {
    @State private var model = LabModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
                .task { await model.loadProgress() }
        }
    }
}
