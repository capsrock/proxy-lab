//
//  EchoPayload.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// エコーサービスの `/get` が返す形。
/// 受け取ったヘッダと URL をそのまま返してくれるので、
/// 「リクエストが書き換わったか」をレスポンスだけで検証できる。
struct EchoPayload: Decodable, Equatable, Sendable {
    let headers: [String: String]
    let url: String

    /// HTTP ヘッダ名は大文字小文字を区別しないので、正規化して引く。
    func header(_ name: String) -> String? {
        headers.normalizedHeaderKeys[name.lowercased()]
    }
}

/// エコーサービスの `/post` が返す形。
/// 受け取ったボディが JSON として読めたときだけ `json` に入って返るので、
/// ここが nil かどうかで「書き換えの途中で JSON を壊したか」まで見分けられる。
struct EchoedRequestBody: Decodable, Equatable, Sendable {
    struct Sent: Decodable, Equatable, Sendable {
        /// キー名は `LabMarkers.planKey` と対。片方だけ変えると判定が黙って通らなくなる。
        let plan: String?
    }

    let json: Sent?
}

/// スクリプトが差し込む 1 要素。判定に必要なのは id だけ。
struct PostStub: Decodable, Equatable, Sendable {
    let id: Int
}

/// Scripting のレッスンで、スクリプトが配列を生やしたあとのレスポンス。
struct ScriptedEcho: Decodable, Equatable, Sendable {
    let items: [PostStub]?
}
