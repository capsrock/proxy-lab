//
//  Verifiers.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// レッスンの判定。すべて `ProbeResult` と `VerificationContext` だけを入力に取る純粋関数なので、
/// Proxyman を動かさずに単体テストできる。
enum Verifiers {

    /// 公開 API が一時的に落ちている・絞られていることがある。
    /// これを黙って「レスポンスを読めませんでした」に丸めると、
    /// ユーザーは自分の Proxyman 操作を疑い続けることになるので、先に切り分けて伝える。
    ///
    /// レッスン 05 だけはエラーステータスが期待値なので、この判定を通さない。
    static func serviceIssue(_ result: ProbeResult) -> Verdict? {
        guard let status = result.statusCode, status >= 400 else { return nil }
        return .failed(reason: String(localized: """
            サーバが HTTP \(status) を返しました。Proxyman の設定ではなく公開 API 側の問題です。
            少し待ってからもう一度実行してください。
            """))
    }

    /// 復号されていないドメインには Map Local も Breakpoint も Script も効かない。
    /// Proxyman は中身を見られないまま素通しするだけなので、どれだけ正しくルールを組んでも変化しない。
    ///
    /// そのとき「まだ本物のレスポンスです」とだけ言われても原因に辿り着けないので、
    /// 証明書チェーンを見て先に切り分ける。
    static func notDecrypted(_ result: ProbeResult) -> Verdict? {
        guard result.failure == nil, !result.certificateSubjects.isEmpty else { return nil }
        guard !CertificateInspector.isProxymanChain(result.certificateSubjects) else { return nil }

        let host = result.host ?? String(localized: "このドメイン")
        return .notYet(reason: String(localized: """
            \(host) の中身が暗号化されたままです。
            中身を読めない状態では、ルールを正しく組んでもレスポンスは変わりません。
            Tools → SSL Proxying List… の Include List に \(host) を追加してください。
            """))
    }

    // MARK: 01 Filter

    /// 絞り込みはレスポンスを変えない。だから答え合わせでしか確かめようがない。
    /// 正解の値は判定文に出さない。出したら、探さずにそこから写せてしまう。
    static func filter(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let echo = result.decode(EchoPayload.self),
            let sentCode = echo.header(LabMarkers.codeHeader)
        else {
            return .notYet(reason: String(localized: "エコーのレスポンスを読めませんでした。"))
        }

        let answer = context.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            return .notYet(reason: String(localized: """
                \(LabMarkers.filterTotalCount) 件のリクエストを送りました。Proxyman で特定のリクエストを検索してください。
                手順どおりに絞り込みの欄で 1 件まで絞り、その `\(LabMarkers.codeHeader.lowercased())` を読んでください。
                読み取った 4 文字を`答え合わせ`の欄に入れると判定します。
                """))
        }
        guard answer.caseInsensitiveCompare(sentCode) == .orderedSame else {
            return .notYet(reason: String(localized: """
                「\(answer)」は、送ったリクエストに付いていた値と違います。
                絞り込みの欄が `\(LabMarkers.filterItemKey)=\(LabMarkers.filterTargetItem)` になっているか確認してください。残るのは 1 件だけです。
                その 1 件の `Response` の `Body` にある `\(LabMarkers.codeHeader.lowercased())` を読んでください。リクエスト側の `Headers` にも同じ値があります。
                """))
        }
        return .cleared(detail: String(localized: """
            よく似た \(LabMarkers.filterTotalCount) 件から目的の 1 件を見つけて、中身を読めました。
            """))
    }

    // MARK: 02 Map Local

    static func mapLocal(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let object = result.jsonObject else {
            return .notYet(reason: String(localized: "レスポンスを JSON として読めませんでした。"))
        }
        guard let marker = object[LabMarkers.mapLocalKey] as? String else {
            return .notYet(reason: String(localized: """
                まだ本物のサーバのレスポンスです。
                \"\(LabMarkers.mapLocalKey)\" キーが見つかりません。
                """))
        }
        guard marker == LabMarkers.mapLocalValue else {
            return .notYet(reason: String(localized: """
                \"\(LabMarkers.mapLocalKey)\" が \"\(marker)\" でした。
                \"\(LabMarkers.mapLocalValue)\" を返すようにしてください。
                """))
        }
        return .cleared(detail: String(localized: "ローカルファイルのレスポンスが返っています。サーバ不要で画面を作れます。"))
    }

    // MARK: 03 Breakpoint (Request)

    static func breakpointRequest(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let echo = result.decode(EchoPayload.self) else {
            return .notYet(reason: String(localized: "エコーのレスポンスを読めませんでした。"))
        }
        guard let token = echo.header(LabMarkers.tokenHeader) else {
            return .notYet(reason: String(localized: "\(LabMarkers.tokenHeader) がサーバに届いていません。"))
        }

        switch token {
        case LabMarkers.tokenGranted:
            return .cleared(detail: String(localized: "送信中のリクエストヘッダを \(LabMarkers.tokenGranted) に書き換えられました。"))
        case LabMarkers.tokenPending:
            return .notYet(reason: String(localized: """
                ヘッダは \(LabMarkers.tokenPending) のまま届きました。
                Breakpoint がリクエストを止められていないか、書き換えずに Execute しています。
                """))
        default:
            return .notYet(reason: String(localized: """
                \"\(token)\" が届きました。ちょうど \(LabMarkers.tokenGranted) にしてください。
                """))
        }
    }

    // MARK: 04 Breakpoint (Request Body)

    static func breakpointBody(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let echo = result.decode(EchoedRequestBody.self) else {
            return .notYet(reason: String(localized: "レスポンスを読めませんでした。"))
        }
        // エコーサービスは、受け取ったボディが JSON として読めたときだけ json に入れて返す。
        // ここが空なら、書き換えの途中でカンマや引用符が落ちている。
        guard let sent = echo.json else {
            return .notYet(reason: String(localized: """
                送ったボディが JSON として届いていません。
                `Body` タブで、カンマや引用符が欠けていないか確認してください。
                """))
        }
        guard let plan = sent.plan else {
            return .notYet(reason: String(localized: """
                ボディに \"\(LabMarkers.planKey)\" が見当たりません。
                キーの名前は変えずに、値だけを書き換えてください。
                """))
        }

        switch plan {
        case LabMarkers.planAfter:
            return .cleared(detail: String(localized: """
                送信の途中でボディを \"\(LabMarkers.planAfter)\" に差し替えられました。アプリもサーバも直していません。
                """))
        case LabMarkers.planBefore:
            return .notYet(reason: String(localized: """
                ボディは \"\(LabMarkers.planBefore)\" のまま届きました。
                ルールの `Breakpoint` で `Request` にチェックが入っているか確認してください。
                止まったら `Body` タブで値を書き換えてから `Execute` を押してください。
                """))
        default:
            return .notYet(reason: String(localized: """
                \"\(plan)\" が届きました。ちょうど \"\(LabMarkers.planAfter)\" にしてください。
                """))
        }
    }

    // MARK: 05 Breakpoint (Response)

    static func breakpointResponse(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let status = result.statusCode else {
            return .notYet(reason: String(localized: "ステータスコードを取得できませんでした。"))
        }
        switch status {
        case LabMarkers.repairedStatus:
            return .cleared(detail: String(localized: "サーバは \(LabMarkers.brokenStatus) を返しましたが、アプリには 200 が届きました。"))
        case LabMarkers.brokenStatus:
            return .notYet(reason: String(localized: """
                まだ \(LabMarkers.brokenStatus) のままです。
                Breakpoint の Response 側にチェックを入れ、Status Code を 200 に変えてください。
                """))
        default:
            return .notYet(reason: String(localized: "HTTP \(status) が届きました。200 に書き換えてください。"))
        }
    }

    // MARK: 06 Map Remote

    static func mapRemote(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let echo = result.decode(EchoPayload.self) else {
            return .notYet(reason: String(localized: "エコーのレスポンスを読めませんでした。"))
        }
        if echo.url.contains(LabMarkers.environmentQuery(LabMarkers.stagingEnvironment)) {
            return .cleared(
                detail: String(localized: "リクエストが \(LabMarkers.stagingEnvironment) に向きました（\(echo.url)）。")
            )
        }
        if echo.url.contains(LabMarkers.environmentQuery(LabMarkers.productionEnvironment)) {
            return .notYet(reason: String(localized: """
                まだ \(LabMarkers.productionEnvironment) に向いています（\(echo.url)）。
                Map Remote のルールが有効か、Map To のクエリまで入力しているか確認してください。
                """))
        }
        return .notYet(reason: String(localized: "想定していない URL に届きました（\(echo.url)）。"))
    }

    // MARK: 07 Scripting

    static func scripting(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        if let notDecrypted = notDecrypted(result) { return notDecrypted }
        if let failure = result.failure { return .failed(reason: failure.message) }

        guard let scripted = result.decode(ScriptedEcho.self) else {
            return .notYet(reason: String(localized: "レスポンスを読めませんでした。スクリプトが JSON を壊していないか確認してください。"))
        }
        guard let items = scripted.items else {
            return .notYet(reason: String(localized: """
                レスポンスに \"\(LabMarkers.injectedArrayKey)\" がまだありません。
                スクリプトが有効になっているか、Matching URLs がこのリクエストに合っているか確認してください。
                """))
        }
        guard items.contains(where: { $0.id == LabMarkers.injectedPostID }) else {
            return .notYet(reason: String(localized: """
                \(items.count) 件のうちに id=\(LabMarkers.injectedPostID) は見つかりませんでした。
                """))
        }
        return .cleared(
            detail: String(localized: "スクリプトが作った \(items.count) 件の配列が届きました。コードでデータを生成できています。")
        )
    }

    // MARK: 09 Network Condition

    static func networkCondition(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        if let issue = serviceIssue(result) { return issue }
        guard let baseline = context.baselineDownloadSeconds else {
            return .failed(reason: String(localized: """
                絞る前の速さがまだ分かりません。
                この画面の `baseline を計測` を先に押してください。絞る前と後を比べて判定します。
                """))
        }
        guard baseline >= LabThresholds.minimumBaselineSeconds else {
            return .failed(reason: String(localized: """
                baseline が短すぎて比べられません（\(formatted(baseline)) 秒）。
                `Enable Network Conditions` を OFF に戻してから、`baseline を計測` を押し直してください。
                """))
        }
        if let failure = result.failure { return .failed(reason: failure.message) }

        let ratio = result.duration / baseline
        guard ratio >= LabThresholds.throttleRatio else {
            // 「絞ってください」だけでは何をすればいいのか分からない。
            // Proxyman のどこを触ると絞れるのかまで書く。
            return .notYet(reason: String(localized: """
                まだ \(formatted(ratio)) 倍にしかなっていません（baseline \(formatted(baseline)) 秒 → \(formatted(result.duration)) 秒）。
                Proxyman の `Tools` → `Network Conditions…` で、そのルールの `Profile` に `3G` が選ばれているか確認してください。
                ウィンドウ下の `Enable Network Conditions` と、一覧のそのルールの `Enable Rule` が両方 ON になっているか確認してください。
                どちらも合っていれば、`3G` より遅い `Edge` を選ぶと差が出ます。
                """))
        }
        return .cleared(detail: String(localized: """
            \(formatted(result.duration)) 秒（baseline の \(formatted(ratio)) 倍）。回線を絞れています。
            """))
    }

    // MARK: 08 Block List

    static func blockList(_ result: ProbeResult, _ context: VerificationContext) -> Verdict {
        switch result.failure {
        case .connectionRefused, .timedOut:
            return .cleared(detail: String(localized: """
                このリクエストだけがサーバに届かなくなりました。一部の API が止まったときの見え方を確認できます。
                """))
        case nil:
            let status = result.statusCode.map(String.init) ?? String(localized: "不明")
            return .notYet(reason: String(localized: "HTTP \(status) が返りました。まだ遮断されていません。"))
        case .some(let failure):
            return .failed(reason: failure.message)
        }
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
