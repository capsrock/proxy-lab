//
//  LabError.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation

/// 通信の失敗を、ラボの判定に必要な粒度まで畳んだもの。
enum LabError: Error, Equatable, Sendable {
    /// 接続が拒否・切断された。Block List のレッスンではこれが成功の合図になる。
    case connectionRefused(String)
    /// TLS は張れたが証明書が信頼されていない。Proxyman が介入していて CA 未信頼の状態。
    case certificateUntrusted(String)
    /// 端末がオフライン。
    case offline
    /// タイムアウト。
    case timedOut
    /// それ以外。
    case transport(String)

    var message: String {
        switch self {
        case .connectionRefused(let detail):
            String(localized: "接続が遮断されました（\(detail)）")
        case .certificateUntrusted(let detail):
            String(localized: "サーバ証明書が信頼されていません（\(detail)）")
        case .offline:
            String(localized: "ネットワークに接続されていません")
        case .timedOut:
            String(localized: "タイムアウトしました")
        case .transport(let detail):
            detail
        }
    }
}
