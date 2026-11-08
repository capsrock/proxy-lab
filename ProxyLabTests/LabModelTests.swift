//
//  LabModelTests.swift
//  ProxyLabTests
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
import Testing
@testable import ProxyLab

@Suite("LabModel の実行フロー")
@MainActor
struct LabModelTests {

    private func model(returning result: ProbeResult, store: InMemoryProgressStore = .init()) -> LabModel {
        LabModel(networking: StubLabNetworking(result: result), store: store)
    }

    @Test("クリアすると進捗に記録される")
    func recordsClearedLesson() async throws {
        let lesson = try #require(LessonCatalog.lesson(.mapLocal))
        let cleared = Fixture.result(
            json: #"{"\#(LabMarkers.mapLocalKey)": "\#(LabMarkers.mapLocalValue)"}"#
        )
        let subject = model(returning: cleared)

        await subject.run(lesson)

        #expect(subject.runState(for: .mapLocal).verdict?.isCleared == true)
        #expect(subject.progress.isCleared(.mapLocal))
    }

    @Test("未達なら進捗に残らない")
    func doesNotRecordUnclearedLesson() async throws {
        let lesson = try #require(LessonCatalog.lesson(.mapLocal))
        let subject = model(returning: Fixture.result(json: #"{"id": 1}"#))

        await subject.run(lesson)

        #expect(subject.progress.isCleared(.mapLocal) == false)
    }

    @Test("クリアした進捗は保存され、読み直せる")
    func persistsProgress() async throws {
        let lesson = try #require(LessonCatalog.lesson(.mapLocal))
        let store = InMemoryProgressStore()
        let cleared = Fixture.result(
            json: #"{"\#(LabMarkers.mapLocalKey)": "\#(LabMarkers.mapLocalValue)"}"#
        )

        await model(returning: cleared, store: store).run(lesson)

        let reloaded = model(returning: cleared, store: store)
        await reloaded.loadProgress()
        #expect(reloaded.progress.isCleared(.mapLocal))
    }

    /// 紛れが飛んでいないと、一覧に絞り込む相手がいない。レッスンとして成立しなくなる。
    @Test("Filter は紛れも含めてまとめて送る")
    func filterSendsNoiseAlongsideTheProbe() async throws {
        let lesson = try #require(LessonCatalog.lesson(.filter))
        let networking = CountingNetworking(result: Fixture.plainEcho())

        await LabModel(networking: networking, store: InMemoryProgressStore()).run(lesson)

        #expect(await networking.sentCount == LabMarkers.filterTotalCount)
    }

    /// 答えを入れ直すたびに紛れごと飛ばすと、Proxyman の一覧が同じ行で埋まる。
    @Test("答え合わせは送り直さずに判定する")
    func submittingAnswerDoesNotResend() async throws {
        let lesson = try #require(LessonCatalog.lesson(.filter))
        let networking = CountingNetworking(
            result: Fixture.echo(
                headers: [LabMarkers.codeHeader.lowercased(): LabMarkers.filterCode],
                url: "https://postman-echo.com/get?lesson=filter&item=code"
            )
        )
        let subject = LabModel(networking: networking, store: InMemoryProgressStore())

        await subject.run(lesson)
        let sentSoFar = await networking.sentCount
        #expect(!subject.progress.isCleared(.filter), "答える前にクリアしてはいけません")

        subject.setAnswer(LabMarkers.filterCode, for: .filter)
        await subject.submitAnswer(for: lesson)

        #expect(await networking.sentCount == sentSoFar)
        #expect(subject.progress.isCleared(.filter))
    }

    @Test("baseline を計測すると保存され、09 の判定に使われる")
    func measuredBaselineFeedsVerification() async throws {
        let lesson = try #require(LessonCatalog.lesson(.networkCondition))
        let subject = model(returning: Fixture.result(json: "[]", duration: 0.5))

        await subject.measureBaseline(for: lesson)

        #expect(subject.progress.baselineDownloadSeconds == 0.5)
    }

    @Test("baseline 計測前に 09 を実行すると failed になる")
    func networkConditionFailsWithoutBaseline() async throws {
        let lesson = try #require(LessonCatalog.lesson(.networkCondition))
        let subject = model(returning: Fixture.result(json: "[]", duration: 5))

        await subject.run(lesson)

        #expect(subject.runState(for: .networkCondition).verdict?.isCleared == false)
    }

    @Test("診断結果が状態に反映される")
    func storesDoctorDiagnosis() async {
        let subject = model(
            returning: Fixture.result(json: "{}", certificates: Fixture.proxymanChain)
        )

        await subject.runDoctor()

        guard case .finished(let diagnosis, _) = subject.doctorState else {
            Issue.record("診断が完了していません")
            return
        }
        #expect(diagnosis.isHealthy)
    }

    /// 準備が済んだ印を付けられるのは診断だけ。ここが保存されないと、
    /// アプリを開き直すたびにレッスン一覧が「まだ準備が済んでいません」に戻る。
    @Test("診断が通ると準備済みとして保存され、読み直せる")
    func doctorMarksSetupComplete() async {
        let store = InMemoryProgressStore()
        let decrypting = Fixture.result(json: "{}", certificates: Fixture.proxymanChain)

        let subject = model(returning: decrypting, store: store)
        #expect(!subject.isSetupComplete)
        await subject.runDoctor()

        #expect(subject.isSetupComplete)

        let reloaded = model(returning: decrypting, store: store)
        await reloaded.loadProgress()
        #expect(reloaded.isSetupComplete)
    }

    @Test("診断が通らなければ準備済みにはならない")
    func doctorKeepsSetupIncompleteWhenNotDecrypting() async {
        let subject = model(
            returning: Fixture.result(json: "{}", certificates: Fixture.realChain, proxy: nil)
        )

        await subject.runDoctor()

        #expect(!subject.isSetupComplete)
    }

    @Test("リセットで進捗も実行状態も消える")
    func resetClearsEverything() async throws {
        let lesson = try #require(LessonCatalog.lesson(.mapLocal))
        let cleared = Fixture.result(
            json: #"{"\#(LabMarkers.mapLocalKey)": "\#(LabMarkers.mapLocalValue)"}"#
        )
        let subject = model(returning: cleared)
        await subject.run(lesson)

        await subject.resetProgress()

        #expect(subject.progress == .empty)
        #expect(subject.runState(for: .mapLocal) == .idle)
    }
}

@Suite("ファイル永続化")
struct FileProgressStoreTests {

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "lab-progress-\(UUID().uuidString).json")
    }

    @Test("保存した進捗を読み直せる")
    func roundTripsProgress() async {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let progress = LabProgress.empty.clearing(.scripting).settingBaseline(1.25)

        await FileProgressStore(fileURL: url).save(progress)

        #expect(await FileProgressStore(fileURL: url).load() == progress)
    }

    @Test("ファイルが無ければ空の進捗から始まる")
    func startsEmptyWhenFileIsMissing() async {
        #expect(await FileProgressStore(fileURL: temporaryURL()).load() == .empty)
    }

    @Test("ファイルが壊れていても空に戻して学習を続けられる")
    func recoversFromCorruptFile() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("これは JSON ではない".utf8).write(to: url)

        #expect(await FileProgressStore(fileURL: url).load() == .empty)
    }

    /// 実際の保存先は "Library/Application Support"。スペースを含むパスで
    /// 読み込みが壊れて進捗が毎回リセットされる不具合があったので、その回帰テスト。
    @Test("スペースを含むディレクトリでも読み書きできる")
    func roundTripsThroughPathWithSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Application Support \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "lab-progress.json")
        let progress = LabProgress.empty.clearing(.mapLocal)

        await FileProgressStore(fileURL: url).save(progress)

        #expect(await FileProgressStore(fileURL: url).load() == progress)
    }
}
