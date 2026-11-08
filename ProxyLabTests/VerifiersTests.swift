//
//  VerifiersTests.swift
//  ProxyLabTests
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
import Testing
@testable import ProxyLab

@Suite("01 Filter")
struct FilterVerifierTests {

    private let sent = Fixture.echo(
        headers: [LabMarkers.codeHeader.lowercased(): LabMarkers.filterCode],
        url: "https://postman-echo.com/get?lesson=filter&item=code"
    )

    private func context(_ answer: String) -> VerificationContext {
        VerificationContext(answer: answer)
    }

    @Test("読み取ったコードが合っていればクリア")
    func clearsWhenTheCodeMatches() {
        #expect(Verifiers.filter(sent, context(LabMarkers.filterCode)).isCleared)
    }

    /// Proxyman はヘッダを小文字で見せる。写した大文字小文字で落とすのは意地悪なだけ。
    @Test("大文字小文字は問わない")
    func ignoresCase() {
        #expect(Verifiers.filter(sent, context(LabMarkers.filterCode.lowercased())).isCleared)
        #expect(Verifiers.filter(sent, context(" \(LabMarkers.filterCode) ")).isCleared)
    }

    /// 送っただけの状態。ここで「未達」とだけ言うと、何を待たれているのか分からない。
    @Test("答えが空なら、次に何をするかを伝える")
    func explainsWhatToDoBeforeAnswering() {
        let verdict = Verifiers.filter(sent, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("\(LabMarkers.filterTotalCount) 件"))
        #expect(verdict.message.withoutMarkup.contains(LabMarkers.codeHeader.lowercased()))
    }

    @Test("違うコードなら、絞り込み方をもう一度案内する")
    func guidesBackToTheFilterWhenWrong() {
        let verdict = Verifiers.filter(sent, context("ZZZZ"))

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("ZZZZ"))
        #expect(
            verdict.message.contains("\(LabMarkers.filterItemKey)=\(LabMarkers.filterTargetItem)")
        )
    }

    /// 判定文に正解を書くと、探さずにそこから写せてしまう。
    @Test("判定文は正解のコードを漏らさない")
    func neverLeaksTheCode() {
        for answer in ["", "ZZZZ"] {
            let message = Verifiers.filter(sent, context(answer)).message
            #expect(
                !message.localizedCaseInsensitiveContains(LabMarkers.filterCode),
                "「\(answer)」への判定文に正解が出ています: \(message)"
            )
        }
    }

    /// 復号できていないと、そもそも Proxyman でレスポンスを開けない。
    @Test("復号されていなければ、先にそれを伝える")
    func reportsUndecryptedFirst() {
        let undecrypted = Fixture.result(
            json: #"{"headers": {}, "url": "https://postman-echo.com/get"}"#,
            certificates: Fixture.realChain
        )

        #expect(Verifiers.filter(undecrypted, context("K7QM")).message.contains("SSL Proxying List"))
    }
}

@Suite("02 Map Local")
struct MapLocalVerifierTests {

    @Test("目印が入っていればクリア")
    func clearsWhenMarkerIsPresent() {
        let result = Fixture.result(
            json: #"{"\#(LabMarkers.mapLocalKey)": "\#(LabMarkers.mapLocalValue)"}"#
        )

        #expect(Verifiers.mapLocal(result, .empty).isCleared)
    }

    @Test("本物のレスポンスのままなら未達")
    func doesNotClearForRealResponse() {
        let result = Fixture.result(json: #"{"userId": 1, "id": 1, "title": "sunt aut"}"#)

        let verdict = Verifiers.mapLocal(result, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains(LabMarkers.mapLocalKey))
    }

    @Test("目印の値が違えば、正しい値を伝える")
    func reportsWrongMarkerValue() {
        let result = Fixture.result(json: #"{"\#(LabMarkers.mapLocalKey)": "typo"}"#)

        let verdict = Verifiers.mapLocal(result, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains(LabMarkers.mapLocalValue))
    }

    @Test("JSON でなければ未達")
    func doesNotClearForNonJSON() {
        #expect(!Verifiers.mapLocal(Fixture.result(json: "not json"), .empty).isCleared)
    }

    @Test("通信自体が失敗していれば failed")
    func failsOnTransportError() {
        let verdict = Verifiers.mapLocal(Fixture.failure(.offline), .empty)

        if case .failed = verdict {} else {
            Issue.record("failed になるはずが \(verdict) でした")
        }
    }
}

@Suite("03 Breakpoint (Request)")
struct BreakpointRequestVerifierTests {

    @Test("GRANTED が届いていればクリア")
    func clearsWhenTokenIsGranted() {
        let result = Fixture.echo(
            headers: [LabMarkers.tokenHeader: LabMarkers.tokenGranted],
            url: "https://postman-echo.com/get"
        )

        #expect(Verifiers.breakpointRequest(result, .empty).isCleared)
    }

    @Test("ヘッダ名の大文字小文字は無視する")
    func matchesHeaderCaseInsensitively() {
        let result = Fixture.echo(
            headers: ["x-lab-token": LabMarkers.tokenGranted],
            url: "https://postman-echo.com/get"
        )

        #expect(Verifiers.breakpointRequest(result, .empty).isCleared)
    }

    @Test("PENDING のままなら Breakpoint の設定を促す")
    func guidesWhenTokenIsStillPending() {
        let result = Fixture.echo(
            headers: [LabMarkers.tokenHeader: LabMarkers.tokenPending],
            url: "https://postman-echo.com/get"
        )

        let verdict = Verifiers.breakpointRequest(result, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("Breakpoint"))
    }

    @Test("別の値なら、その値を理由に含める")
    func reportsUnexpectedToken() {
        let result = Fixture.echo(
            headers: [LabMarkers.tokenHeader: "granted"],
            url: "https://postman-echo.com/get"
        )

        let verdict = Verifiers.breakpointRequest(result, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("granted"))
    }

    @Test("ヘッダが届いていなければ未達")
    func doesNotClearWhenHeaderIsMissing() {
        let result = Fixture.echo(headers: ["Host": "httpbin.org"], url: "https://postman-echo.com/get")

        #expect(!Verifiers.breakpointRequest(result, .empty).isCleared)
    }
}

@Suite("04 Breakpoint (Request Body)")
struct BreakpointBodyVerifierTests {

    @Test("本文が書き換わっていればクリア")
    func clearsWhenPlanIsUpgraded() {
        #expect(Verifiers.breakpointBody(Fixture.echoedBody(plan: LabMarkers.planAfter), .empty).isCleared)
    }

    @Test("そのままなら Request 側のチェックと Body タブを促す")
    func guidesWhenBodyIsUntouched() {
        let verdict = Verifiers.breakpointBody(Fixture.echoedBody(plan: LabMarkers.planBefore), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.withoutMarkup.contains("Request"))
        #expect(verdict.message.withoutMarkup.contains("Body"))
    }

    @Test("別の値なら、その値を理由に含める")
    func reportsUnexpectedPlan() {
        let verdict = Verifiers.breakpointBody(Fixture.echoedBody(plan: "premium"), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("premium"))
    }

    /// 書き換えの途中でカンマや引用符を落とすと、サーバは本文を JSON として読めない。
    /// 「plan がありません」と言うと、キー名を疑わせてしまう。
    @Test("JSON を壊した場合は、その旨だけを伝える")
    func reportsBrokenJSON() {
        let verdict = Verifiers.breakpointBody(
            Fixture.result(json: #"{"data": "{\"plan\": \"pro\"", "json": null}"#),
            .empty
        )

        #expect(!verdict.isCleared)
        #expect(verdict.message.withoutMarkup.contains("JSON として届いていません"))
        #expect(!verdict.message.contains("キーの名前"))
    }

    @Test("キーごと消えていれば、値だけ書き換えるよう伝える")
    func guidesWhenKeyIsMissing() {
        let verdict = Verifiers.breakpointBody(
            Fixture.result(json: #"{"json": {"\#(LabMarkers.planUserKey)": 1}}"#),
            .empty
        )

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains(LabMarkers.planKey))
        #expect(verdict.message.contains("キーの名前"))
    }
}

@Suite("05 Breakpoint (Response)")
struct BreakpointResponseVerifierTests {

    @Test("200 に書き換わっていればクリア")
    func clearsWhenStatusIsRepaired() {
        let result = Fixture.result(json: "{}", status: LabMarkers.repairedStatus)

        #expect(Verifiers.breakpointResponse(result, .empty).isCleared)
    }

    @Test("500 のままなら Response 側のチェックを促す")
    func guidesWhenStatusIsStillBroken() {
        let result = Fixture.result(json: "{}", status: LabMarkers.brokenStatus)

        let verdict = Verifiers.breakpointResponse(result, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("Response"))
    }

    @Test("別のステータスなら、その値を理由に含める")
    func reportsUnexpectedStatus() {
        let verdict = Verifiers.breakpointResponse(Fixture.result(json: "{}", status: 404), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("404"))
    }
}

@Suite("06 Map Remote")
struct MapRemoteVerifierTests {

    @Test("staging に向いていればクリア")
    func clearsWhenRedirectedToStaging() {
        let result = Fixture.echo(headers: [:], url: "https://postman-echo.com/get?env=staging")

        #expect(Verifiers.mapRemote(result, .empty).isCleared)
    }

    @Test("production のままなら未達で、届いた URL を示す")
    func showsURLWhenStillProduction() {
        let url = "https://postman-echo.com/get?env=production"
        let verdict = Verifiers.mapRemote(Fixture.echo(headers: [:], url: url), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains(url))
    }

    @Test("想定外の URL なら未達")
    func doesNotClearForUnexpectedURL() {
        let result = Fixture.echo(headers: [:], url: "https://postman-echo.com/get?env=other")

        #expect(!Verifiers.mapRemote(result, .empty).isCleared)
    }
}

@Suite("07 Scripting")
struct ScriptingVerifierTests {

    @Test("注入した id があればクリア")
    func clearsWhenInjectedIDIsPresent() {
        let result = Fixture.scripted(ids: [LabMarkers.injectedPostID, 9998, 9997])

        #expect(Verifiers.scripting(result, .empty).isCleared)
    }

    @Test("配列がまだ無ければ、スクリプトの有効化を促す")
    func guidesWhenArrayIsMissing() {
        let verdict = Verifiers.scripting(Fixture.plainEcho(), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains(LabMarkers.injectedArrayKey))
    }

    @Test("別の id しか無ければ未達で、件数を伝える")
    func reportsCountWhenIDIsMissing() {
        let verdict = Verifiers.scripting(Fixture.scripted(ids: [1, 2, 3]), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("3 件"))
    }

    @Test("スクリプトが JSON を壊した場合は未達")
    func doesNotClearWhenBodyIsBroken() {
        #expect(!Verifiers.scripting(Fixture.result(json: "{items: ["), .empty).isCleared)
    }
}

@Suite("09 Network Condition")
struct NetworkConditionVerifierTests {

    private let context = VerificationContext(baselineDownloadSeconds: 0.5)

    @Test("baseline の 3 倍以上遅ければクリア")
    func clearsWhenSlowEnough() {
        let result = Fixture.result(json: "[]", duration: 1.5)

        #expect(Verifiers.networkCondition(result, context).isCleared)
    }

    /// 「もっと絞ってください」だけでは手が動かない。
    /// いまどれだけ絞れているかと、Proxyman のどこを触るかの両方を出す。
    @Test("まだ速ければ、現状の倍率と絞り方の両方を伝える")
    func guidesWhenNotSlowEnough() {
        let verdict = Verifiers.networkCondition(Fixture.result(json: "[]", duration: 0.6), context)

        #expect(!verdict.isCleared)
        #expect(verdict.summary.contains("1.20 倍"))
        #expect(verdict.details.contains { $0.withoutMarkup.contains("Network Conditions") })
        #expect(verdict.details.contains { $0.withoutMarkup.contains("Profile") })
    }

    @Test("baseline 未計測なら failed")
    func failsWithoutBaseline() {
        let verdict = Verifiers.networkCondition(Fixture.result(json: "[]", duration: 5), .empty)

        if case .failed = verdict {} else {
            Issue.record("failed になるはずが \(verdict) でした")
        }
    }

    @Test("baseline が短すぎるときは計測し直しを促す")
    func failsWhenBaselineIsTooShort() {
        let tiny = VerificationContext(baselineDownloadSeconds: 0.001)

        let verdict = Verifiers.networkCondition(Fixture.result(json: "[]", duration: 5), tiny)

        if case .failed = verdict {} else {
            Issue.record("failed になるはずが \(verdict) でした")
        }
    }
}

@Suite("08 Block List")
struct BlockListVerifierTests {

    @Test("接続が遮断されていればクリア")
    func clearsWhenConnectionRefused() {
        #expect(Verifiers.blockList(Fixture.failure(.connectionRefused("reset")), .empty).isCleared)
    }

    @Test("タイムアウトもクリア扱い")
    func clearsOnTimeout() {
        #expect(Verifiers.blockList(Fixture.failure(.timedOut), .empty).isCleared)
    }

    @Test("普通に成功したら未達で、ステータスを示す")
    func reportsStatusWhenNotBlocked() {
        let verdict = Verifiers.blockList(Fixture.result(json: "{}", status: 200), .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("200"))
    }

    @Test("オフラインは遮断と区別する")
    func distinguishesOfflineFromBlocked() {
        let verdict = Verifiers.blockList(Fixture.failure(.offline), .empty)

        #expect(!verdict.isCleared)
        if case .failed = verdict {} else {
            Issue.record("failed になるはずが \(verdict) でした")
        }
    }
}

@Suite("公開 API 側の障害の切り分け")
struct ServiceIssueTests {

    /// 04 は 500 が期待値なので、このガードを通してはいけない。
    private let verifiersGuardingServiceIssues:
        [(String, @Sendable (ProbeResult, VerificationContext) -> Verdict)] = [
            ("01", Verifiers.filter),
            ("02", Verifiers.mapLocal),
            ("03", Verifiers.breakpointRequest),
            ("04", Verifiers.breakpointBody),
            ("06", Verifiers.mapRemote),
            ("07", Verifiers.scripting),
        ]

    @Test("503 は「公開 API 側の問題」として報告する")
    func reportsServiceOutage() {
        let outage = Fixture.result(json: "<html>Service Unavailable</html>", status: 503)

        for (lesson, verify) in verifiersGuardingServiceIssues {
            let verdict = verify(outage, .empty)

            #expect(verdict.message.contains("503"), "\(lesson) が 503 を伝えていません")
            #expect(verdict.message.contains("公開 API"), "\(lesson) が原因の所在を伝えていません")
            if case .failed = verdict {} else {
                Issue.record("\(lesson) は failed になるはずが \(verdict) でした")
            }
        }
    }

    @Test("429 のようなレート制限も同様に切り分ける")
    func reportsRateLimit() {
        let limited = Fixture.result(json: "{}", status: 429)

        #expect(Verifiers.mapLocal(limited, .empty).message.contains("429"))
    }

    @Test("05 は 500 を期待値として扱い、障害と混同しない")
    func breakpointResponseTreatsErrorStatusAsExpected() {
        let verdict = Verifiers.breakpointResponse(
            Fixture.result(json: "{}", status: LabMarkers.brokenStatus),
            .empty
        )

        #expect(verdict.message.contains("Response"))
        #expect(!verdict.message.contains("公開 API"))
    }

    @Test("09 は障害を baseline 未計測より先に報告する")
    func networkConditionReportsOutageBeforeBaseline() {
        let verdict = Verifiers.networkCondition(Fixture.result(json: "{}", status: 503), .empty)

        #expect(verdict.message.contains("503"))
    }
}
