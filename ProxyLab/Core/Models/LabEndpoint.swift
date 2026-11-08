//
//  LabEndpoint.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// ラボが叩く公開エンドポイント。
///
/// **すべて同じホストに揃えてある。** ホストが分かれていると、
/// レッスンごとに SSL Proxying List へ登録し直す羽目になるため。
/// レッスン同士は URL のクエリで区別し、Proxyman のルールが互いに干渉しないようにする。
enum LabEndpoint: Sendable, Equatable {
    /// リクエストのヘッダと URL をそのままエコーする。
    case echo
    /// エコー + レッスンを見分けるクエリ。
    case echoForLesson(String)
    /// エコー + レッスン 01 の通し番号。
    /// よく似た URL を並べて、一覧を絞り込まないと目的の 1 件に辿り着けない状態を作る。
    case echoForFilterItem(String)
    /// エコー + 環境名のクエリ（Map Remote の検証に使う）。
    case echoWithEnvironment(String)
    /// 送った本文をそのまま返す。「リクエストの中身が書き換わったか」を見るのに使う。
    case echoBody
    /// Network Conditions で速度差を測れる 1 MB のレスポンス。
    case largePayload
    /// 指定したステータスコードを返す。
    case status(Int)
    /// 他のレッスンとパスが重ならない、遮断テスト専用のエンドポイント。
    case time
}

/// エンドポイント群のホスト定義。
struct LabHost: Sendable, Equatable {
    /// リクエストをそのまま返してくれるサービス。
    /// 「リクエストが書き換わったか」をレスポンスだけで検証できるのがここの役割。
    let echoService: URL

    /// サーバ構築なしで動く既定の構成。
    static let publicAPIs = LabHost(echoService: requireURL("https://postman-echo.com"))

    /// SSL Proxying List に登録してもらうドメイン。1 つで済む。
    var domain: String { echoService.host() ?? "" }

    func resolve(_ endpoint: LabEndpoint) -> URL {
        switch endpoint {
        case .echo:
            get
        case .echoForLesson(let lesson):
            get.appending(queryItems: [URLQueryItem(name: LabMarkers.lessonKey, value: lesson)])
        case .echoForFilterItem(let item):
            get.appending(
                queryItems: [
                    URLQueryItem(name: LabMarkers.lessonKey, value: LabMarkers.filterLesson),
                    URLQueryItem(name: LabMarkers.filterItemKey, value: item),
                ]
            )
        case .echoWithEnvironment(let environment):
            get.appending(
                queryItems: [URLQueryItem(name: LabMarkers.environmentKey, value: environment)]
            )
        case .echoBody:
            echoService.appending(path: "post")
        case .largePayload:
            echoService
                .appending(path: "bytes")
                .appending(path: "1")
                .appending(path: "mb")
                .appending(
                    queryItems: [
                        URLQueryItem(name: "type", value: "json"),
                        URLQueryItem(name: LabMarkers.lessonKey, value: "speed"),
                    ]
                )
        case .status(let code):
            echoService.appending(path: "status").appending(path: String(code))
        case .time:
            echoService.appending(path: "time").appending(path: "now")
        }
    }

    private var get: URL { echoService.appending(path: "get") }
}

/// 定数として書かれた URL 文字列を解決する。
/// 失敗するのは実装ミスのときだけなので、実行時ではなくビルド直後に気づけるよう停止させる。
private func requireURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
        preconditionFailure("LabHost に不正な URL が書かれています: \(string)")
    }
    return url
}
