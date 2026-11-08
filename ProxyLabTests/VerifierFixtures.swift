//
//  VerifierFixtures.swift
//  ProxyLabTests
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
@testable import ProxyLab

extension String {
    /// 表示用の印（バッククォート）を外した素の文章。
    /// 手順の中身を確かめたいだけのテストが、印の有無に振り回されないようにする。
    var withoutMarkup: String { replacingOccurrences(of: "`", with: "") }
}

/// テスト用に `ProbeResult` を組み立てるヘルパー。
/// 判定関数が純粋なので、実際に通信しなくてもここで全ケースを再現できる。
enum Fixture {

    /// 既定は「Proxyman で復号済み」。02 以降のレッスンはそれが前提なので、
    /// 素の証明書のままだと復号されていない旨の切り分けが先に返ってしまう。
    static func result(
        json: String,
        status: Int = 200,
        duration: TimeInterval = 0.1,
        certificates: [String] = Fixture.proxymanChain,
        proxy: String? = nil,
        failure: LabError? = nil
    ) -> ProbeResult {
        ProbeResult(
            host: "postman-echo.com",
            statusCode: status,
            body: Data(json.utf8),
            duration: duration,
            certificateSubjects: certificates,
            proxyInUse: proxy,
            failure: failure
        )
    }

    static func failure(
        _ error: LabError,
        duration: TimeInterval = 0.1,
        certificates: [String] = [],
        proxy: String? = nil,
        networkAvailable: Bool? = true
    ) -> ProbeResult {
        ProbeResult(
            duration: duration,
            certificateSubjects: certificates,
            proxyInUse: proxy,
            networkAvailable: networkAvailable,
            failure: error
        )
    }

    /// エコーサービスが返す形。
    static func echo(headers: [String: String], url: String) -> ProbeResult {
        let headerEntries = headers
            .map { "\"\($0.key)\": \"\($0.value)\"" }
            .joined(separator: ", ")
        return result(json: #"{"headers": {\#(headerEntries)}, "url": "\#(url)"}"#)
    }

    /// エコーサービスの /post が、受け取った本文をそのまま返した形。
    static func echoedBody(plan: String) -> ProbeResult {
        result(
            json: #"""
                {"json": {"\#(LabMarkers.planUserKey)": \#(LabMarkers.planUserID), "\#(LabMarkers.planKey)": "\#(plan)"}}
                """#
        )
    }

    /// スクリプトが items 配列を生やしたあとのレスポンス。
    static func scripted(ids: [Int]) -> ProbeResult {
        let entries = ids.map { #"{"id": \#($0)}"# }.joined(separator: ", ")
        return result(json: #"{"url": "https://postman-echo.com/get", "items": [\#(entries)]}"#)
    }

    /// スクリプトがまだ効いていない、素のエコー。
    static func plainEcho() -> ProbeResult {
        result(json: #"{"url": "https://postman-echo.com/get", "headers": {}}"#)
    }

    static let proxymanChain = ["postman-echo.com", "Proxyman CA (Hideo's MacBook Pro)"]
    static let realChain = ["postman-echo.com", "YE2", "Root YE", "ISRG Root X2"]
    static let proxyAddress = "127.0.0.1:9090"
}

/// 何本投げられたかを数えるスタブ。紛れが実際に飛んでいるかを確かめるために使う。
actor CountingNetworking: LabNetworking {
    private(set) var sentCount = 0
    private let result: ProbeResult

    init(result: ProbeResult) {
        self.result = result
    }

    func send(_ probe: Probe) async -> ProbeResult {
        sentCount += 1
        return result
    }
}
