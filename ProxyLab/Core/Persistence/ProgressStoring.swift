//
//  ProgressStoring.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation

protocol ProgressStoring: Sendable {
    func load() async -> LabProgress
    func save(_ progress: LabProgress) async
}

/// テスト用。メモリ上だけで完結する。
actor InMemoryProgressStore: ProgressStoring {
    private var stored: LabProgress

    init(initial: LabProgress = .empty) {
        self.stored = initial
    }

    func load() -> LabProgress { stored }

    func save(_ progress: LabProgress) { stored = progress }
}
