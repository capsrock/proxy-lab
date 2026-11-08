//
//  LabModel.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
import Observation

/// レッスン 1 件の実行状態。
enum RunState: Sendable, Equatable {
    case idle
    case running
    case finished(Verdict, ProbeResult)

    var isRunning: Bool { self == .running }

    var verdict: Verdict? {
        if case .finished(let verdict, _) = self { return verdict }
        return nil
    }

    var result: ProbeResult? {
        if case .finished(_, let result) = self { return result }
        return nil
    }
}

enum DoctorState: Sendable, Equatable {
    case idle
    case running
    case finished(Diagnosis, ProbeResult)
}

/// 画面が参照する唯一の状態。通信と永続化はプロトコル越しに注入する。
@MainActor
@Observable
final class LabModel {

    private(set) var progress: LabProgress = .empty
    private(set) var runs: [LessonID: RunState] = [:]
    /// 答えの欄があるレッスンで、ユーザーが入力した文字列。
    private(set) var answers: [LessonID: String] = [:]
    private(set) var doctorState: DoctorState = .idle
    private(set) var isMeasuringBaseline = false

    private let networking: LabNetworking
    private let store: any ProgressStoring

    init(
        networking: LabNetworking = URLSessionLabNetworking(),
        store: any ProgressStoring = FileProgressStore()
    ) {
        self.networking = networking
        self.store = store
    }

    func loadProgress() async {
        progress = await store.load()
    }

    // MARK: レッスンの実行

    func runState(for id: LessonID) -> RunState {
        runs[id] ?? .idle
    }

    func run(_ lesson: Lesson) async {
        guard !runState(for: lesson.id).isRunning else { return }
        runs[lesson.id] = .running

        // 紛れは判定に使う 1 本と同時に投げる。先に流し切ると、目的の 1 件だけが
        // 一覧のいちばん新しい行になり、絞り込まなくても見つかってしまう。
        async let primary = networking.send(lesson.probe)
        await sendNoise(lesson.noise)
        let result = await primary

        await finish(lesson, with: result)
    }

    /// 送り直さずに、直前のレスポンスをもう一度判定する。
    /// 答えを入れ直すたびに紛れごと飛ばすと、Proxyman の一覧が同じ行で埋まって読めなくなる。
    func submitAnswer(for lesson: Lesson) async {
        guard let result = runState(for: lesson.id).result else { return }
        await finish(lesson, with: result)
    }

    func answer(for lessonID: LessonID) -> String {
        answers[lessonID] ?? ""
    }

    func setAnswer(_ text: String, for lessonID: LessonID) {
        answers[lessonID] = text
    }

    func clearRunResult(for lessonID: LessonID) {
        if case .finished = runs[lessonID] {
            runs[lessonID] = .idle
        }
    }

    private func finish(_ lesson: Lesson, with result: ProbeResult) async {
        let verdict = lesson.verify(result, verificationContext(for: lesson.id))
        runs[lesson.id] = .finished(verdict, result)

        guard verdict.isCleared, !progress.isCleared(lesson.id) else { return }
        await update(progress.clearing(lesson.id))
    }

    /// 判定には使わない。Proxyman の一覧によく似た行を並べるためだけに投げる。
    private func sendNoise(_ probes: [Probe]) async {
        guard !probes.isEmpty else { return }
        let networking = networking
        await withTaskGroup(of: Void.self) { group in
            for probe in probes {
                group.addTask { _ = await networking.send(probe) }
            }
        }
    }

    /// 復号できていないと Map Local も Breakpoint も効かない。
    /// レッスンは開けるようにしたうえで、まだここが済んでいないことを一覧の案内で伝える。
    var isSetupComplete: Bool {
        progress.isSetupComplete
    }

    private func verificationContext(for lessonID: LessonID) -> VerificationContext {
        VerificationContext(
            baselineDownloadSeconds: progress.baselineDownloadSeconds,
            answer: answer(for: lessonID)
        )
    }

    // MARK: 回線速度の baseline

    /// レッスン 09 用に、絞る前の所要時間を測っておく。
    func measureBaseline(for lesson: Lesson) async {
        guard !isMeasuringBaseline else { return }
        isMeasuringBaseline = true
        defer { isMeasuringBaseline = false }

        let result = await networking.send(lesson.probe)
        guard result.failure == nil else {
            runs[lesson.id] = .finished(
                .failed(reason: String(localized: "baseline の計測に失敗しました: \(result.failure?.message ?? "")")),
                result
            )
            return
        }
        await update(progress.settingBaseline(result.duration))
    }

    func clearBaseline() async {
        guard progress.baselineDownloadSeconds != nil else { return }
        await update(progress.clearingBaseline())
    }

    // MARK: セットアップ診断

    func runDoctor() async {
        guard doctorState != .running else { return }
        doctorState = .running

        let result = await networking.send(Probe(endpoint: .echo, timeout: 15))
        let diagnosis = SetupDoctor.diagnose(result)
        doctorState = .finished(diagnosis, result)

        // 準備が済んだ印はここでしか付かない。レッスン側には同じことを判定する回が無い。
        guard diagnosis.isHealthy, !progress.isSetupComplete else { return }
        await update(progress.completingSetup())
    }

    func clearDoctorResult() {
        if case .finished = doctorState {
            doctorState = .idle
        }
    }

    // MARK: 進捗

    func resetProgress() async {
        runs.removeAll()
        answers.removeAll()
        doctorState = .idle
        await update(.empty)
    }

    private func update(_ newProgress: LabProgress) async {
        progress = newProgress
        await store.save(newProgress)
    }
}
