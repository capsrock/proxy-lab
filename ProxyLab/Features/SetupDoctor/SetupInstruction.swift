//
//  SetupInstruction.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 準備の手順のうち、複数の場所に出てくるもの。
///
/// 「SSL Proxying が有効か確かめる」は iPhone シミュレータの手順・実機の手順・診断のアドバイスの
/// 3 箇所に出る。文面をそれぞれに書くと、直すときに 1 箇所忘れて食い違う。
enum SetupInstruction {

    /// 文中に置くドメイン。
    ///
    /// `postman-echo.com` をそのまま流し込むと、SwiftUI がハイフンで折り返して
    /// 「postman-」「echo.com」と割れる。ドメインが 2 行に割れると別物に見えるので、
    /// 表示用だけノーブレークハイフン（U+2011）にして割れないようにする。
    private static let domain = LabHost.publicAPIs.domain
        .replacingOccurrences(of: "-", with: "\u{2011}")

    // 実機の手順は iPhone 側と Mac 側を行き来する。
    // どちらを触るのかを毎回文頭に書かないと、手元とにらめっこして迷う。

    /// 一覧のリクエストを右クリックする方法は使わない。
    /// 準備の段階ではまだ 1 度も通信しておらず、Proxyman の一覧が空で右クリックする対象が無い。
    /// ドメインを直接登録する方なら、通信ゼロの状態でも先に済ませられる。
    static let enableSSLProxying =
        String(localized: "Mac の Proxyman で `Tools` → `SSL Proxying List…` を開き、`Include List` の「+」を押して、下の `Domain` を貼り付けて `Add` する。`Enable SSL Proxying Tool` が ON になっていることを確認する。")

    /// 手順の文中のドメインは折り返し対策で加工してあり、そのままでは貼り付けられない。
    /// 実際に入力する値は必ずこちらから取る。全レッスンがこの 1 ドメインだけを使う。
    static let sslProxyingDomain = CopyableValue(
        label: "Domain",
        value: LabHost.publicAPIs.domain
    )

    static let trustRootCertificate =
        String(localized: "iPhone の `設定` → `一般` → `情報` → `証明書信頼設定` で Proxyman CA の `ルート証明書を完全に信頼` を ON にする。")

    static let installCertificateOnDevice =
        String(localized: "Mac の Proxyman で `Certificate` → `Install Certificate on iOS` → `Physical Devices…` を開き、証明書をインストールする。")

    /// 再起動まで書く。インストール直後は信頼ストアに反映されず、
    /// そのまま診断すると「証明書がまだ信頼されていません」で 1 回落ちる。
    static let installCertificateOnSimulator =
        String(localized: "Mac の Proxyman で `Certificate` → `Install Certificate on iOS` → `Simulators…` を開き、証明書をインストールしたあと、シミュレータを再起動する。")

    /// シミュレータでも実機でも読めるように、戻る先はデバイス名ではなく「アプリ」と書く。
    static let confirmWithDoctor =
        String(localized: "このアプリに戻って `診断する` を押し、結果が `セットアップ完了` になることを確認する。")
}
