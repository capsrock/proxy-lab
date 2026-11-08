//
//  SupportingTests.swift
//  ProxyLabTests
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
import Testing
@testable import ProxyLab

@Suite("証明書チェーンの判定")
struct CertificateInspectorTests {

    @Test("Proxyman を含む Subject を検出する")
    func detectsProxymanSubject() {
        #expect(CertificateInspector.isProxymanChain(Fixture.proxymanChain))
    }

    @Test("大文字小文字は無視する")
    func matchesCaseInsensitively() {
        #expect(CertificateInspector.isProxymanChain(["PROXYMAN CA"]))
    }

    @Test("本物のチェーンは検出しない")
    func ignoresRealChain() {
        #expect(!CertificateInspector.isProxymanChain(Fixture.realChain))
    }

    @Test("空のチェーンは検出しない")
    func ignoresEmptyChain() {
        #expect(!CertificateInspector.isProxymanChain([]))
    }
}

@Suite("エンドポイントの URL 生成")
struct LabEndpointTests {

    private let host = LabHost.publicAPIs

    @Test("エコーは /get")
    func resolvesEcho() {
        #expect(host.resolve(.echo).absoluteString == "https://postman-echo.com/get")
    }

    @Test("レッスン名はクエリとして載る")
    func resolvesLessonQuery() {
        #expect(
            host.resolve(.echoForLesson("map-local")).absoluteString
                == "https://postman-echo.com/get?lesson=map-local"
        )
    }

    @Test("フィルタのレッスンはレッスン名と通し番号の 2 つをクエリに載せる")
    func resolvesFilterItemQuery() {
        #expect(
            host.resolve(.echoForFilterItem("07")).absoluteString
                == "https://postman-echo.com/get?lesson=filter&item=07"
        )
    }

    @Test("環境名もクエリとして載る")
    func resolvesEnvironmentQuery() {
        #expect(
            host.resolve(.echoWithEnvironment(LabMarkers.productionEnvironment)).absoluteString
                == "https://postman-echo.com/get?env=production"
        )
    }

    @Test("ステータス指定")
    func resolvesStatus() {
        #expect(host.resolve(.status(500)).absoluteString == "https://postman-echo.com/status/500")
    }

    @Test("速度計測は1 MBレスポンスを使う")
    func resolvesLargePayload() {
        #expect(
            host.resolve(.largePayload).absoluteString
                == "https://postman-echo.com/bytes/1/mb?type=json&lesson=speed"
        )
    }

    /// ホストが分かれていると SSL Proxying List への登録が増える。1 つに揃っていることを固定する。
    @Test("全エンドポイントが同じホストを使う")
    func everyEndpointSharesOneHost() {
        let endpoints: [LabEndpoint] = [
            .echo, .echoForLesson("x"), .echoForFilterItem("01"), .echoBody,
            .echoWithEnvironment("y"), .largePayload, .status(500), .time,
        ]

        for endpoint in endpoints {
            #expect(host.resolve(endpoint).host() == host.domain)
        }
    }

    /// 同じ /get を叩くレッスンが複数あるので、Proxyman のルールが混ざらないよう URL を分ける。
    @Test("レッスンごとに URL が重複しない")
    func lessonURLsAreDistinct() {
        let urls = LessonCatalog.all.map { host.resolve($0.probe.endpoint).absoluteString }

        #expect(Set(urls).count == urls.count, "URL が重複しています: \(urls)")
    }

    @Test("ホストを差し替えると全エンドポイントが追従する")
    func followsHostSwap() {
        let custom = LabHost(echoService: URL(string: "https://lab.example.com/api")!)

        #expect(custom.resolve(.echo).absoluteString == "https://lab.example.com/api/get")
        #expect(custom.domain == "lab.example.com")
    }
}

@Suite("復号されていないドメインの切り分け")
struct NotDecryptedGuardTests {

    /// 準備で追加したドメイン以外を使うレッスンで、
    /// 「まだ本物のレスポンスです」とだけ言われて原因に辿り着けない事故を防ぐ。
    private let undecrypted = ProbeResult(
        host: "postman-echo.com",
        statusCode: 200,
        body: Data(#"{"userId": 1, "id": 1}"#.utf8),
        certificateSubjects: Fixture.realChain
    )

    @Test("復号されていないと、そのホスト名を挙げて SSL Proxying List に誘導する")
    func namesTheHostThatIsNotDecrypted() {
        let verdict = Verifiers.mapLocal(undecrypted, .empty)

        #expect(!verdict.isCleared)
        #expect(verdict.message.contains("postman-echo.com"))
        #expect(verdict.message.contains("SSL Proxying List"))
    }

    @Test("ルールが効かない全レッスンで同じ切り分けが出る")
    func appliesToEveryRuleBasedLesson() {
        let verifiers: [(String, @Sendable (ProbeResult, VerificationContext) -> Verdict)] = [
            ("02", Verifiers.mapLocal),
            ("03", Verifiers.breakpointRequest),
            ("04", Verifiers.breakpointBody),
            ("05", Verifiers.breakpointResponse),
            ("06", Verifiers.mapRemote),
            ("07", Verifiers.scripting),
        ]

        for (lesson, verify) in verifiers {
            #expect(
                verify(undecrypted, .empty).message.contains("SSL Proxying List"),
                "\(lesson) が復号されていないことを伝えていません"
            )
        }
    }

    @Test("復号できていれば、この切り分けは出ない")
    func staysQuietWhenDecrypted() {
        let decrypted = ProbeResult(
            host: "postman-echo.com",
            statusCode: 200,
            body: Data(#"{"userId": 1}"#.utf8),
            certificateSubjects: Fixture.proxymanChain
        )

        #expect(Verifiers.notDecrypted(decrypted) == nil)
        #expect(!Verifiers.mapLocal(decrypted, .empty).message.contains("SSL Proxying List"))
    }

    /// SSL Proxying List への登録は準備で 1 回だけ済ませる。
    /// レッスンが別ホストを叩くようになると、そのレッスンだけ黙って動かなくなる。
    @Test("全レッスンが、準備で登録させた 1 ドメインだけを使う")
    func everyLessonUsesTheSingleRegisteredDomain() {
        let host = LabHost.publicAPIs

        #expect(SetupInstruction.sslProxyingDomain.value == host.domain)

        for lesson in LessonCatalog.all {
            for probe in [lesson.probe] + lesson.noise {
                #expect(
                    host.resolve(probe.endpoint).host() == host.domain,
                    "\(lesson.id.rawValue) が別のホストを叩いています"
                )
            }
        }
    }
}

@Suite("レッスンカタログ")
struct LessonCatalogTests {

    @Test("すべての LessonID にレッスンが定義されている")
    func coversEveryLessonID() {
        for id in LessonID.allCases {
            #expect(LessonCatalog.lesson(id) != nil, "\(id.rawValue) が未定義です")
        }
    }

    @Test("番号が 1 から連番になっている")
    func numbersAreSequential() {
        #expect(LessonCatalog.all.map(\.number) == Array(1...LessonCatalog.all.count))
    }

    @Test("どのレッスンにも手順とゴールがある")
    func everyLessonIsDocumented() {
        for lesson in LessonCatalog.all {
            #expect(!lesson.steps.isEmpty, "\(lesson.id.rawValue) に手順がありません")
            #expect(!lesson.goal.isEmpty, "\(lesson.id.rawValue) にゴールがありません")
        }
    }

    /// 絞り込む相手が無ければ、絞り込みの練習にならない。
    @Test("Filter は、よく似たリクエストを 12 件まとめて送る")
    func filterLessonSendsALookalikeBurst() throws {
        let lesson = try #require(LessonCatalog.lesson(.filter))
        let host = LabHost.publicAPIs
        let urls = ([lesson.probe] + lesson.noise).map { host.resolve($0.endpoint).absoluteString }

        #expect(urls.count == LabMarkers.filterTotalCount)
        #expect(Set(urls).count == urls.count, "紛れの URL が重複しています")
        // どれも同じ /get。一覧の見た目では区別が付かないからこそ、検索欄が要る。
        #expect(urls.allSatisfy { $0.contains("/get?\(LabMarkers.lessonKey)=\(LabMarkers.filterLesson)") })
    }

    /// 目的の 1 件にしか付いていないから、探し当てた証拠になる。
    @Test("Filter のコードは、判定に使う 1 本にだけ載る")
    func filterCodeRidesOnlyOnTheTarget() throws {
        let lesson = try #require(LessonCatalog.lesson(.filter))

        #expect(lesson.probe.headers[LabMarkers.codeHeader] == LabMarkers.filterCode)
        #expect(lesson.noise.allSatisfy { $0.headers[LabMarkers.codeHeader] == nil })
        #expect(lesson.answer != nil, "答えの欄が無いと、見たことを確かめられません")
    }

    /// アプリが答えを表示してしまうと、Proxyman を開かずにクリアできる。
    @Test("Filter のコードは画面のどこにも出ない")
    func filterCodeNeverAppearsOnScreen() throws {
        let lesson = try #require(LessonCatalog.lesson(.filter))
        let prompt = try #require(lesson.answer)
        let onScreen = (
            [lesson.title, lesson.feature, lesson.goal, prompt.title, prompt.placeholder, prompt.hint]
                + lesson.steps.map(\.text)
                + lesson.inputs.map(\.label)
                + lesson.inputs.map(\.value)
                + [lesson.material?.content ?? "", lesson.material?.purpose ?? ""]
        ).joined(separator: "\n")

        #expect(!onScreen.localizedCaseInsensitiveContains(LabMarkers.filterCode))
    }

    @Test("Breakpoint のレッスンは PENDING を送る")
    func breakpointLessonSendsPendingToken() {
        let lesson = LessonCatalog.lesson(.breakpointRequest)

        #expect(lesson?.probe.headers[LabMarkers.tokenHeader] == LabMarkers.tokenPending)
    }

    @Test("Breakpointは操作待ちのため長いタイムアウトを使う")
    func breakpointLessonsUseInteractiveTimeout() throws {
        for id in [LessonID.breakpointRequest, .breakpointBody, .breakpointResponse] {
            let lesson = try #require(LessonCatalog.lesson(id))
            #expect(lesson.probe.timeout == 300, "\(id.rawValue) のタイムアウトが短すぎます")
        }
    }

    /// 本文が無ければ、Breakpoint の Body タブに書き換える相手が出ない。
    @Test("04 は書き換えてもらう JSON を POST する")
    func breakpointBodyLessonPostsJSON() throws {
        let lesson = try #require(LessonCatalog.lesson(.breakpointBody))

        #expect(lesson.probe.endpoint == .echoBody)
        #expect(lesson.probe.body.httpMethod == "POST")

        let sent = try #require(lesson.probe.body.data)
        let object = try #require(
            try JSONSerialization.jsonObject(with: sent) as? [String: Any]
        )
        #expect(object[LabMarkers.planKey] as? String == LabMarkers.planBefore)
        #expect(object[LabMarkers.planUserKey] as? Int == LabMarkers.planUserID)
    }

    /// 止めた画面に出るのはアプリが実際に送る本文。素材と食い違うと、探す相手が変わってしまう。
    @Test("04 の素材は、実際に送る本文と同じ中身")
    func breakpointBodyMaterialMatchesTheProbe() throws {
        let lesson = try #require(LessonCatalog.lesson(.breakpointBody))
        let material = try #require(lesson.material)
        let sent = try #require(lesson.probe.body.data)

        #expect(material.kind == .json)

        let fromMaterial = try #require(
            try JSONSerialization.jsonObject(with: Data(material.content.utf8)) as? [String: Any]
        )
        let fromProbe = try #require(try JSONSerialization.jsonObject(with: sent) as? [String: Any])

        #expect(fromMaterial[LabMarkers.planKey] as? String == fromProbe[LabMarkers.planKey] as? String)
        #expect(
            fromMaterial[LabMarkers.planUserKey] as? Int == fromProbe[LabMarkers.planUserKey] as? Int
        )
    }

    @Test("Breakpointはコピー済み表示と実際の変更を区別して説明する")
    func breakpointInstructionsExplainCopyStatus() throws {
        let lesson = try #require(LessonCatalog.lesson(.breakpointRequest))
        let instructions = lesson.steps.map(\.text).joined(separator: "\n").withoutMarkup

        #expect(instructions.contains("コピー済み表示"))
        #expect(instructions.contains("実際に書き換える"))
        #expect(instructions.contains("GRANTED になったことを確認"))
    }

    @Test("Breakpoint ResponseはStatus Codeの入力場所を説明する")
    func breakpointResponseInstructionsNameStatusCodeLocation() throws {
        let lesson = try #require(LessonCatalog.lesson(.breakpointResponse))
        let instructions = lesson.steps.map(\.text).joined(separator: "\n").withoutMarkup

        #expect(instructions.contains("Response 欄で Other タブ"))
        #expect(instructions.contains("Status Code の欄"))
        #expect(instructions.contains("500 から 200"))
    }

    @Test("クエリ付きのMatching RuleはWildcard形式で一致する")
    func queryMatchingRulesUseWildcardSyntax() throws {
        for id in [LessonID.mapLocal, .breakpointRequest, .scripting] {
            let lesson = try #require(LessonCatalog.lesson(id))
            let value = try #require(lesson.inputs.first?.value)

            #expect(value.contains("*lesson="), "\(id.rawValue) のクエリ開始がWildcard形式ではありません: \(value)")
            #expect(!value.contains("?lesson="), "\(id.rawValue) に未エスケープの ? が残っています: \(value)")
        }
    }

    @Test("素材つきレッスンの中身は空でない")
    func materialsAreNotEmpty() {
        for lesson in LessonCatalog.all {
            guard let material = lesson.material else { continue }
            #expect(!material.content.isEmpty, "\(lesson.id.rawValue) の素材が空です")
        }
    }

    /// 素材だけ見て何に使うのか分からないと、手順まで戻る羽目になる。
    @Test("素材には用途が書いてある")
    func materialsExplainTheirPurpose() {
        for lesson in LessonCatalog.all {
            guard let material = lesson.material else { continue }
            #expect(!material.purpose.isEmpty, "\(lesson.id.rawValue) の素材に用途がありません")
        }
    }

    /// Select Local File で使う素材は、HTTP メッセージ全体ではなく JSON 本文にする。
    @Test("Map Local の素材はJSON本文だけ")
    func mapLocalMaterialIsJSONBody() throws {
        let material = try #require(LessonCatalog.lesson(.mapLocal)?.material)

        #expect(material.kind == .json)
        #expect(!material.content.hasPrefix("HTTP/1.1"))
        #expect((try? JSONSerialization.jsonObject(with: Data(material.content.utf8))) != nil)
        #expect(material.content.contains(LabMarkers.mapLocalKey))
    }

    /// 手順の文章に URL を書くと、画面上で選択もコピーもできない。
    /// 貼り付ける値は必ず inputs に置く。
    @Test("手順の文章に URL を埋め込まない")
    func stepsDoNotEmbedURLs() {
        for lesson in LessonCatalog.all {
            for step in lesson.steps {
                #expect(
                    !step.text.contains("https://"),
                    "\(lesson.id.rawValue) の手順に URL が埋まっています: \(step.text)"
                )
            }
        }
    }

    @Test("Proxyman に何か入力するレッスンには、コピーできる値がある")
    func lessonsWithInputFieldsProvideCopyableValues() {
        for lesson in LessonCatalog.all where lesson.steps.contains(where: { $0.text.contains("貼り付ける") }) {
            #expect(!lesson.inputs.isEmpty, "\(lesson.id.rawValue) に貼り付ける値がありません")
        }
    }

    /// 値をまとめて別のセクションに置くと、手順を読んだ場所に値が無く「何を貼るのか」が分からなくなる。
    @Test("貼り付ける値は、それを使う手順に紐付いている")
    func valuesAreAttachedToTheStepThatUsesThem() {
        for lesson in LessonCatalog.all {
            for step in lesson.steps where step.value != nil {
                #expect(
                    step.text.contains("この値"),
                    "\(lesson.id.rawValue) の手順が値を指していません: \(step.text)"
                )
            }
        }
    }

    @Test("「この値」と書いた手順には必ず値が付いている")
    func stepsThatPromiseAValueHaveOne() {
        for lesson in LessonCatalog.all {
            for step in lesson.steps where step.text.contains("この値") {
                #expect(step.value != nil, "\(lesson.id.rawValue): \(step.text) に値がありません")
            }
        }
    }

    @Test("コピーできる値はラベルも中身も空でなく、重複しない")
    func copyableValuesAreWellFormed() {
        for lesson in LessonCatalog.all {
            for input in lesson.inputs {
                #expect(!input.label.isEmpty, "\(lesson.id.rawValue) にラベルの無い値があります")
                #expect(!input.value.isEmpty, "\(lesson.id.rawValue) に中身の無い値があります")
            }
            let labels = lesson.inputs.map(\.label)
            #expect(Set(labels).count == labels.count, "\(lesson.id.rawValue) にラベルの重複があります")
        }
    }

    @Test("Map Remote は Protocol / Host / Path / Query を欄ごとに渡す")
    func mapRemoteProvidesPerFieldValues() throws {
        let lesson = try #require(LessonCatalog.lesson(.mapRemote))
        let labels = lesson.inputs.map(\.label)

        for expected in ["Protocol", "Host", "Path"] {
            #expect(
                labels.contains { $0.hasPrefix(expected) },
                "\(expected) の欄がありません"
            )
        }

        let from = try #require(lesson.inputs.first { $0.label.contains("Map From") }).value
        let to = try #require(lesson.inputs.first { $0.label.contains("Map To") }).value
        #expect(from == LabMarkers.environmentQuery(LabMarkers.productionEnvironment))
        #expect(to == LabMarkers.environmentQuery(LabMarkers.stagingEnvironment))
    }

    @Test("Map Remoteは有効化確認を含む")
    func mapRemoteExplainsEnablingTheTool() throws {
        let lesson = try #require(LessonCatalog.lesson(.mapRemote))
        #expect(lesson.steps.contains { $0.text.contains("Enable Map Remote Tool") })
    }

    @Test("ScriptingはResponse実行を有効化する")
    func scriptingEnablesResponseExecution() throws {
        let lesson = try #require(LessonCatalog.lesson(.scripting))
        #expect(lesson.steps.contains { $0.text.contains("Run Script on Response") })
    }

    @Test("Network Conditionsは3Gプリセットと1 MB URLを使う")
    func networkConditionUsesPresetAndLargePayload() throws {
        let lesson = try #require(LessonCatalog.lesson(.networkCondition))

        #expect(lesson.probe.endpoint == .largePayload)
        #expect(lesson.steps.contains { $0.text.contains("3G") })
        #expect(!lesson.steps.contains { $0.text.contains("Delay:") })
    }

    /// Proxyman の各ダイアログのボタン名は Save と Done が混在している。
    /// nib から読み取った実物に合っているかを、代表的なものだけ固定しておく。
    @Test("確定ボタンの名前が画面ごとに正しい")
    func confirmButtonNamesMatchTheRealUI() throws {
        let usesDone: [LessonID] = [.breakpointRequest, .breakpointResponse, .mapRemote, .blockList]
        for id in usesDone {
            let steps = try #require(LessonCatalog.lesson(id)?.steps)
            #expect(
                steps.contains { $0.text.withoutMarkup.contains("Done を押す") },
                "\(id.rawValue) は Done のはずです"
            )
        }

        let mapLocalSteps = try #require(LessonCatalog.lesson(.mapLocal)?.steps)
        #expect(mapLocalSteps.contains { $0.text.withoutMarkup.contains("Save を押す") })
    }
}

/// レッスン 09 は 1 MB の JSON を受け取る。丸ごと `Text` に渡すと SwiftUI が描画を諦めて
/// 画面に何も出なくなったので、表示用の本文は必ず頭で切る。
@Suite("生レスポンスの表示")
struct DisplayBodyTests {

    @Test("短い JSON はそのまま整形して出す")
    func showsSmallJSONInFull() {
        let result = ProbeResult(body: Data(#"{"id":1}"#.utf8))

        #expect(result.displayBody.contains("\"id\" : 1"))
        #expect(!result.displayBody.contains("先頭だけ"))
    }

    @Test("1 MB のレスポンスは切り詰めて、全体の大きさを伝える")
    func clipsHugeResponse() {
        let huge = Data(#"{"filler":"\#(String(repeating: "a", count: 1_048_576))"}"#.utf8)
        let result = ProbeResult(body: huge)

        #expect(result.displayBody.count < 2_200)
        #expect(result.displayBody.contains("\(huge.count) バイト"))
    }

    @Test("行数が多いときも切り詰める")
    func clipsManyLines() {
        let manyLines = (1...500).map { "line \($0)" }.joined(separator: "\n")
        let result = ProbeResult(body: Data(manyLines.utf8))

        let lines = result.displayBody.split(separator: "\n")
        #expect(lines.count <= 31)
        #expect(result.displayBody.contains("先頭だけ"))
    }

    @Test("空のボディは空のまま")
    func leavesEmptyBodyAlone() {
        #expect(ProbeResult().displayBody.isEmpty)
    }
}

/// 「プロキシを通していない」と「プロキシは通しているが向こうが落ちている」は原因が別。
/// 前者は端末の設定、後者は Mac の Proxyman を見に行くことになるので、混ぜない。
@Suite("プロキシが繋がらないときの切り分け")
struct ProxyReachabilityTests {

    @Test("プロキシ設定があるのに届かないなら、Proxyman の起動を疑わせる")
    func blamesProxymanWhenProxyIsConfiguredButDead() {
        let result = Fixture.failure(
            .connectionRefused("Could not connect to the server."),
            proxy: Fixture.proxyAddress
        )

        let diagnosis = SetupDoctor.diagnose(result)

        #expect(diagnosis == .proxyUnreachable(
            proxy: Fixture.proxyAddress,
            detail: LabError.connectionRefused("Could not connect to the server.").message
        ))
        #expect(diagnosis.headline.contains("プロキシに繋がりません"))
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("Proxyman が起動しているか") })
        // Wi-Fi を疑わせない。繋がっていないのはプロキシの先だけ。
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("Wi-Fi に繋がっているか") })
    }

    @Test("プロキシ設定が無いまま届かないなら、オフラインとして扱う")
    func reportsOfflineWhenNoProxyIsConfigured() {
        let result = Fixture.failure(.connectionRefused("lost"), proxy: nil)

        let diagnosis = SetupDoctor.diagnose(result)

        if case .offline = diagnosis {} else {
            Issue.record("offline になるはずが \(diagnosis) でした")
        }
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("Wi-Fi に繋がっているか") })
    }

    /// 「プロキシを経由していない」は観測結果であって原因ではない。
    /// 実行先まで見れば原因はほぼ特定できるので、そこまで言い切る。
    @Test("シミュレータでプロキシが無いなら、Proxyman の未起動を指す")
    func blamesProxymanOnSimulator() {
        let diagnosis = SetupDoctor.diagnose(
            Fixture.result(json: "{}", certificates: Fixture.realChain, proxy: nil),
            environment: .simulator
        )

        #expect(diagnosis.headline == "Mac の Proxyman が起動していません")
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("Proxyman を起動") })
        // シミュレータでは要らない手順なので出さない。
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("HTTP プロキシ") })
    }

    @Test("実機でプロキシが無いなら、iPhone 側の設定を指す")
    func blamesDeviceSettingsOnDevice() {
        let diagnosis = SetupDoctor.diagnose(
            Fixture.result(json: "{}", certificates: Fixture.realChain, proxy: nil),
            environment: .device
        )

        #expect(diagnosis.headline == "iPhone にプロキシが設定されていません")
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("HTTP プロキシ") })
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("9090") })
    }

}

/// 証明書の入れ方は実行先で別物になる。両方並べると、自分に関係ない手順を
/// 読ませることになり、実機で「シミュレータを再起動」を探しにいってしまう。
@Suite("証明書が信頼されていないときの案内")
struct CertificateTrustAdviceTests {

    private static let untrusted = Fixture.failure(
        .certificateUntrusted("A TLS error caused the secure connection to fail."),
        certificates: Fixture.proxymanChain,
        proxy: Fixture.proxyAddress
    )

    @Test("シミュレータでは Simulators へのインストールだけを出す")
    func showsSimulatorInstallOnly() {
        let diagnosis = SetupDoctor.diagnose(Self.untrusted, environment: .simulator)

        #expect(diagnosis.headline == "証明書がまだ信頼されていません")
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("Simulators") })
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("Physical Devices") })
        // シミュレータは信頼ストアに直接入るので、証明書信頼設定の操作は無い。
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("証明書信頼設定") })
    }

    @Test("実機ではインストールと証明書信頼設定の両方を出す")
    func showsDeviceInstallAndTrustToggle() {
        let diagnosis = SetupDoctor.diagnose(Self.untrusted, environment: .device)

        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("Physical Devices") })
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("証明書信頼設定") })
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("Simulators") })
    }

}

/// 機内モードや圏外でも、端末のプロキシ設定は残ったままになる。
/// 先にネットワークの可否を見ないと、Mac を触っても直らない案内をしてしまう。
@Suite("端末が圏外のときの切り分け")
struct OfflineDiagnosisTests {

    @Test("圏外なら、プロキシ設定があってもオフラインとして扱う")
    func prefersOfflineOverProxyFailure() {
        let result = Fixture.failure(
            .connectionRefused("The network connection was lost."),
            proxy: "127.0.0.1:9494",
            networkAvailable: false
        )

        let diagnosis = SetupDoctor.diagnose(result)

        #expect(diagnosis.headline == "インターネットに接続されていません")
        #expect(diagnosis.advice.contains { $0.withoutMarkup.contains("機内モード") })
        // Mac を疑わせない。iPhone が外に出られていないだけ。
        #expect(!diagnosis.advice.contains { $0.withoutMarkup.contains("Proxyman が起動しているか") })
    }

    @Test("インターネットに繋がっているなら、プロキシの不調として扱う")
    func blamesProxyWhenNetworkIsFine() {
        let result = Fixture.failure(
            .connectionRefused("refused"),
            proxy: "127.0.0.1:9494",
            networkAvailable: true
        )

        #expect(SetupDoctor.diagnose(result).headline == "プロキシに繋がりません")
    }
}

/// 手順の書き方をひとつに保つ。読み手が同じ操作を毎回違う言い方で読まされないように。
///
/// 表記の決め:
/// - 英字の UI 名はそのまま書く（ラテン文字は日本語の中で十分目立つ）
/// - 日本語の UI 名は「」で囲む（囲まないと文に溶ける）
/// - ラベル末尾のコロンは書かない。欄であることは「〜の欄」で示す
/// - 入力欄に値を置く操作は「入れる」
/// - トグルの確認は「〜が ON になっていることを確認する」
@Suite("手順の表記")
struct InstructionStyleTests {

    private var allInstructions: [(String, String)] {
        LessonCatalog.all.flatMap { lesson in
            lesson.steps.map { (lesson.id.rawValue, $0.text) }
        }
    }

    @Test("UI 名にラベルのコロンを書かない")
    func doesNotCarryLabelColons() {
        for (lesson, text) in allInstructions {
            #expect(
                text.range(of: "[A-Za-z][A-Za-z ]*:\\s*(の|で|に|は|を|欄)", options: .regularExpression) == nil,
                "\(lesson): コロン付きのラベルが残っています → \(text)"
            )
        }
    }

    @Test("入力欄に値を置く操作は「入れる」で書く")
    func usesOneVerbForInput() {
        for (lesson, text) in allInstructions where text.contains("の欄") {
            #expect(
                !text.contains("入力する") && !text.contains("貼り付ける"),
                "\(lesson): 入力の言い方が揃っていません → \(text)"
            )
        }
    }

    @Test("トグルの確認は同じ言い方にする")
    func usesOnePhraseForToggles() {
        for (lesson, text) in allInstructions where text.contains("ON") {
            #expect(
                !text.contains("ON か確認"),
                "\(lesson): 「ON になっていることを確認する」に揃えてください → \(text)"
            )
        }
    }
}
