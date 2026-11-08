//
//  LabNetworking.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation

/// Probe を撃つ側の抽象。テストでは固定の `ProbeResult` を返すスタブに差し替える。
protocol LabNetworking: Sendable {
    func send(_ probe: Probe) async -> ProbeResult
}

/// テスト用。決め打ちの結果を返す。
struct StubLabNetworking: LabNetworking {
    let result: ProbeResult

    func send(_ probe: Probe) async -> ProbeResult { result }
}
