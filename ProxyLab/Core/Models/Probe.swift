//
//  Probe.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 送信するリクエストの本文。
///
/// メソッドを別に持たせない。GET に本文は無く、本文があれば POST しかないので、
/// 「本文なしの POST」のような組み合わせを最初から作れないようにしておく。
enum ProbeBody: Sendable, Equatable {
    case none
    /// JSON 本文を付けて POST する。
    case json(String)

    var httpMethod: String {
        switch self {
        case .none: "GET"
        case .json: "POST"
        }
    }

    var data: Data? {
        switch self {
        case .none: nil
        case .json(let text): Data(text.utf8)
        }
    }

    var contentType: String? {
        switch self {
        case .none: nil
        case .json: "application/json"
        }
    }
}

/// レッスンが 1 本だけ撃つリクエストの定義。
struct Probe: Sendable, Equatable {
    let endpoint: LabEndpoint
    let headers: [String: String]
    let body: ProbeBody
    let timeout: TimeInterval

    static let defaultTimeout: TimeInterval = 30

    init(
        endpoint: LabEndpoint,
        headers: [String: String] = [:],
        body: ProbeBody = .none,
        timeout: TimeInterval = Probe.defaultTimeout
    ) {
        self.endpoint = endpoint
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}
