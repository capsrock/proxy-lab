//
//  Diagnosis.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// どこで動いているか。
///
/// 「プロキシを通っていない」の原因は実行先で変わる。
/// シミュレータは Mac の通信設定をそのまま使うので、プロキシが無い＝Mac 側に設定が無い、
/// つまり Proxyman が起動していない。実機は自分でプロキシを入れる必要があるので、
/// 設定し忘れが原因になる。観測結果だけを伝えても次に何をすればいいか分からないため、
/// ここまで踏み込んで言い分ける。
enum RunEnvironment: Equatable, Sendable {
    case simulator
    case device

    static var current: RunEnvironment {
        #if targetEnvironment(simulator)
        .simulator
        #else
        .device
        #endif
    }
}

/// セットアップ診断の結果。最初に詰まった段でストップし、そこの対処だけを出す。
enum Diagnosis: Equatable, Sendable {
    /// インターネットに接続されていない。
    case offline(detail: String)
    /// プロキシは設定されているのに、その先が応答しない。
    /// 転送先で Proxyman が起動していないか、IP・ポートが違う。
    case proxyUnreachable(proxy: String, detail: String)
    /// Proxyman が介入しているが、ルート証明書が信頼されていない。
    /// 証明書の入れ方も、そのあと信頼する操作の要否も実行先で変わるので、環境も持たせる。
    case certificateNotTrusted(detail: String, environment: RunEnvironment)
    /// プロキシを一切経由していない。原因は実行先で変わるので、環境も持たせる。
    case notProxied(issuers: [String], environment: RunEnvironment)
    /// プロキシは経由しているが、このドメインが復号されていない（トンネルのみ）。
    /// 証明書だけでは `notProxied` と区別がつかないので、プロキシ設定と併せて判定する。
    case tunnelingOnly(proxy: String, issuers: [String])
    /// Proxyman 経由で復号できている。
    case decrypting(issuers: [String])
    /// それ以外の失敗。
    case unknownFailure(detail: String)

    var isHealthy: Bool {
        if case .decrypting = self { return true }
        return false
    }

    var resultStatus: ResultStatus {
        switch self {
        case .decrypting:
            .cleared
        // 設定が足りないだけで、何も壊れていない。ここに ✗ を出すと、
        // 手順の途中にいる人に「やり方を間違えた」と思わせる。
        case .certificateNotTrusted, .notProxied, .tunnelingOnly:
            .notYet
        // 通信そのものが成立していない。
        case .offline, .proxyUnreachable, .unknownFailure:
            .failed
        }
    }

    var headline: String {
        switch self {
        case .offline: String(localized: "インターネットに接続されていません")
        case .proxyUnreachable: String(localized: "HTTPプロキシに繋がりません")
        case .certificateNotTrusted: String(localized: "証明書がまだ信頼されていません")
        // 観測できたのは「プロキシを通っていない」だが、それだけ言われても手が動かない。
        // 実行先から原因はほぼ特定できるので、原因の方を見出しにする。
        case .notProxied(_, .simulator): String(localized: "Mac の Proxyman が起動していません")
        case .notProxied(_, .device): String(localized: "iPhone にHTTPプロキシが設定されていません")
        // この画面が答えるのは「準備できたか」の一点。仕組みの説明は advice に置く。
        // 「復号できています」のような手段の名前を見出しに出しても、
        // これから使う人には合否が読み取れない。
        case .tunnelingOnly: String(localized: "あと 1 つ、設定が足りません")
        case .decrypting: String(localized: "セットアップ完了")
        case .unknownFailure: String(localized: "診断できませんでした")
        }
    }

    var advice: [String] {
        switch self {
        case .offline:
            // 見出しが状況を言っているので、ここでは対処だけを書く。
            [
                String(localized: "機内モードになっていないか確認してください。"),
                String(localized: "Wi-Fi に繋がっているか確認してください。"),
            ]
        case .proxyUnreachable(let proxy, _):
            [
                String(localized: "\(proxy) にHTTPプロキシの設定は入っていますが、その先が応答しません。"),
                String(localized: "Mac 上で Proxyman が起動しているか確認してください。"),
                String(localized: "iPhone のHTTPプロキシに設定した IPアドレスが Mac の IPアドレス と一致しているか確認してください。"),
            ]
        case .certificateNotTrusted(_, .simulator):
            [
                String(localized: "通信は Proxyman まで届いています。あと一歩です。"),
                SetupInstruction.installCertificateOnSimulator,
            ]
        // 実機はインストールしただけでは信頼されない。ここを飛ばしたまま
        // 「入れたのに変わらない」で止まる人が多いので、2 段に分けて書く。
        case .certificateNotTrusted(_, .device):
            [
                String(localized: "通信は Proxyman まで届いています。あと一歩です。"),
                SetupInstruction.installCertificateOnDevice,
                SetupInstruction.trustRootCertificate,
            ]
        case .tunnelingOnly(let proxy, _):
            [
                String(localized: "\(proxy) は通っていて、Proxyman の一覧にも出ます。ただし中身は暗号化されたままで読めません。"),
                String(localized: "既定では通信内容を読むことはできません。SSL Proxying にドメインを追加すると読むことができます。"),
                SetupInstruction.enableSSLProxying,
                String(localized: "それでも変わらない場合は、実機なら \(SetupInstruction.trustRootCertificate)"),
            ]
        case .notProxied(_, .simulator):
            [
                String(localized: "シミュレータは Mac の通信設定をそのまま使います。Proxyman が起動していないと考えられます。"),
                String(localized: "Mac で Proxyman を起動してください。起動するだけでHTTPプロキシが設定され、シミュレータで通信することができます。"),
                String(localized: "すでに起動している場合は、Proxyman が受信を止めていないか確認してください。"),
            ]
        case .notProxied(_, .device):
            [
                String(localized: "実機にHTTPプロキシを設定する必要があります。"),
                String(localized: "`設定` → `Wi-Fi` → 接続中のネットワークの ⓘ → `HTTP プロキシ` を `手動` にしてください。"),
                String(localized: "`サーバ` の欄に Mac の IP アドレス、`ポート` の欄に 9090 を入れてください。"),
                String(localized: "あわせて、Mac で Proxyman が起動しているかも確認してください。"),
            ]
        case .decrypting:
            [
                String(localized: "Mac の Proxyman で、このアプリが送信したリクエストと受信したレスポンスを読むことができます。"),
                String(localized: "ホームに戻って、レッスンを順に進めてください。"),
            ]
        case .unknownFailure(let detail):
            [detail]
        }
    }

    var issuerSummary: String? {
        switch self {
        case .notProxied(let issuers, _), .decrypting(let issuers), .tunnelingOnly(_, let issuers):
            issuers.isEmpty ? nil : issuers.joined(separator: " / ")
        default:
            nil
        }
    }
}

enum SetupDoctor {
    /// 診断も純粋関数にしておき、実際に通信しなくてもテストできるようにする。
    /// 実行先は既定で自動判定するが、テストでは両方を指定できるようにしておく。
    static func diagnose(
        _ result: ProbeResult,
        environment: RunEnvironment = .current
    ) -> Diagnosis {
        if let failure = result.failure {
            // 端末がそもそも外に出られていないなら、そこで話は終わり。
            // 機内モードでも端末のプロキシ設定は残るので、先にこれを見ないと
            // 「プロキシに繋がりません → Proxyman を確認して」と Mac を疑わせてしまう。
            if result.networkAvailable == false {
                return .offline(detail: failure.message)
            }

            switch failure {
            case .offline:
                return .offline(detail: failure.message)
            case .certificateUntrusted:
                return .certificateNotTrusted(detail: failure.message, environment: environment)
            case .connectionRefused, .timedOut:
                // プロキシ設定はあるのに届かない＝転送先で誰も待ち受けていない。
                // これを「オフライン」に丸めると、Proxyman が落ちているだけなのに
                // Wi-Fi を疑わせることになる。
                if let proxy = result.proxyInUse {
                    return .proxyUnreachable(proxy: proxy, detail: failure.message)
                }
                return .offline(detail: failure.message)
            case .transport:
                return .unknownFailure(detail: failure.message)
            }
        }

        let issuers = result.certificateSubjects
        if CertificateInspector.isProxymanChain(issuers) {
            return .decrypting(issuers: issuers)
        }
        // 証明書が本物でもプロキシは経由していることがある。ここを区別しないと、
        // 起動済みの Proxyman に対して「起動しているか確認」と案内してしまう。
        if let proxy = result.proxyInUse {
            return .tunnelingOnly(proxy: proxy, issuers: issuers)
        }
        return .notProxied(issuers: issuers, environment: environment)
    }
}
