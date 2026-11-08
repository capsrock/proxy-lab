//
//  ProbeResult.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// Probe を撃った結果。判定関数の唯一の入力なので、
/// 判定に必要なものはすべてここに入れる（＝判定を純粋関数に保つ）。
struct ProbeResult: Sendable, Equatable {
    /// 叩いたホスト名。復号されていないドメインを名指しで案内するために持つ。
    let host: String?
    let statusCode: Int?
    /// HTTP レスポンスヘッダ。キーは小文字に正規化済み。
    let headers: [String: String]
    let body: Data
    /// リクエスト送信から受信完了までの秒数。
    let duration: TimeInterval
    /// サーバ証明書チェーンの Subject 一覧（ルートに近い側を含む）。
    let certificateSubjects: [String]
    /// このリクエストに使われたプロキシ（"127.0.0.1:9090" など）。使われなければ nil。
    let proxyInUse: String?
    /// 失敗したとき、端末がそもそもネットワークに出られていたか。確認しなかった場合は nil。
    /// 機内モードや圏外を、プロキシの不調と取り違えないために持つ。
    let networkAvailable: Bool?
    let failure: LabError?

    init(
        host: String? = nil,
        statusCode: Int? = nil,
        headers: [String: String] = [:],
        body: Data = Data(),
        duration: TimeInterval = 0,
        certificateSubjects: [String] = [],
        proxyInUse: String? = nil,
        networkAvailable: Bool? = nil,
        failure: LabError? = nil
    ) {
        self.host = host
        self.statusCode = statusCode
        self.headers = headers.normalizedHeaderKeys
        self.body = body
        self.duration = duration
        self.certificateSubjects = certificateSubjects
        self.proxyInUse = proxyInUse
        self.networkAvailable = networkAvailable
        self.failure = failure
    }
}

// MARK: - ボディの読み取り

extension ProbeResult {
    var bodyText: String {
        String(data: body, encoding: .utf8) ?? String(localized: "<\(body.count) バイトのバイナリ>")
    }

    /// 整形した JSON 文字列。JSON でなければ生テキストを返す。
    var prettyBody: String {
        guard
            let object = try? JSONSerialization.jsonObject(with: body),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let text = String(data: pretty, encoding: .utf8)
        else { return bodyText }
        return text
    }

    /// 画面に出す本文。
    ///
    /// レッスン 09 は 1 MB の JSON を受け取る。丸ごと `Text` に渡すと SwiftUI が描画を諦めて
    /// 何も出なくなるので、頭だけを見せて残りがあることを伝える。
    /// 整形も小さいときだけにする。1 MB の pretty-print は描画の前に時間を食うだけで、
    /// どのみち全部は読めない。
    var displayBody: String {
        let text = body.count <= Self.prettyPrintByteLimit ? prettyBody : bodyText
        let clipped = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(Self.displayLineLimit)
            .joined(separator: "\n")
            .prefix(Self.displayCharacterLimit)

        guard clipped.count < text.count else { return text }
        return String(localized: "\(clipped)\n…（先頭だけ表示しています。全 \(body.count) バイト）")
    }

    private static let prettyPrintByteLimit = 32_768
    private static let displayLineLimit = 30
    private static let displayCharacterLimit = 2_000

    /// トップレベルが辞書の JSON として読む。
    var jsonObject: [String: Any]? {
        try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: body)
    }
}

extension [String: String] {
    /// HTTP ヘッダ名は大文字小文字を区別しないので、比較の前に揃えておく。
    var normalizedHeaderKeys: [String: String] {
        reduce(into: [:]) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
    }
}
