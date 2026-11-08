//
//  LessonDetailView.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

struct LessonDetailView: View {
    let lesson: Lesson

    @Environment(LabModel.self) private var model
    @State private var showResultAlert = false
    @State private var resultAlertMessage = ""
    @State private var resultAlertStatus: ResultStatus = .failed
    /// 実行を始めた時刻。経過時間を出すために持つ。
    @State private var runStartedAt: Date?
    @State private var baselineStartedAt: Date?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                goalSection
                stepsSection

                if let material = lesson.material {
                    MaterialSection(material: material)
                }

                if lesson.id == .networkCondition {
                    baselineSection
                }

                runSection

                if let prompt = lesson.answer {
                    answerSection(prompt)
                }

                if let verdict = runState.verdict {
                    verdictSection(verdict)
                        .id("lesson-result")
                }
                // 答えを聞くレッスンでは生レスポンスを出さない。
                // 読み取ってほしい値がそのまま載っているので、出した時点で探す必要がなくなる。
                if lesson.answer == nil, let result = runState.result {
                    RawResponseSection(result: result)
                }
            }
            .navigationTitle("\(lesson.displayNumber) \(lesson.feature)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                model.clearRunResult(for: lesson.id)
                // 07 の baseline は毎回測り直させる。前回の値を残すと、
                // 回線状況が変わったあとの結果と比べることになる。
                if lesson.id == .networkCondition {
                    Task { await model.clearBaseline() }
                }
            }
            .onChange(of: runState) { _, newState in
                guard case .finished(let verdict, _) = newState else { return }
                runStartedAt = nil
                resultAlertStatus = ResultStatus(verdict)
                // オーバーレイは結論だけ。対処は下の判定セクションに並ぶ。
                resultAlertMessage = verdict.summary
                showResultAlert = true

                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("lesson-result", anchor: .top)
                }
            }
            .overlay {
                if showResultAlert {
                    ResultOverlay(
                        status: resultAlertStatus,
                        message: resultAlertMessage
                    ) {
                        showResultAlert = false
                    }
                }
            }
        }
    }

    private var runState: RunState {
        model.runState(for: lesson.id)
    }

    private var goalSection: some View {
        Section {
            Text(lesson.goal)
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            // セクション見出しの既定は secondary。`.primary` は階層スタイルなので
            // この文脈では secondary に解決されてしまうため、具体的な Color を渡す。
            Text(lesson.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary)
                .textCase(nil)
                .padding(.bottom, 2)
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach(Array(lesson.steps.enumerated()), id: \.element.id) { index, step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .trailing)
                        Text(step.text.instructionText)
                            .font(.callout)
                    }

                    // 貼り付ける値は、それを使う手順のすぐ下に出す。
                    // 別のセクションにまとめると「下の値」がどれなのか探させることになる。
                    if let value = step.value {
                        CopyableValueRow(value: value)
                            .padding(.leading, 26)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "Proxyman での手順"),
                systemImage: "list.number"
            )
        }
    }

    private var baselineSection: some View {
        Section {
            Button {
                baselineStartedAt = .now
                Task {
                    await model.measureBaseline(for: lesson)
                    baselineStartedAt = nil
                }
            } label: {
                HStack {
                    Text("baseline を計測")
                    Spacer()
                    if model.isMeasuringBaseline {
                        ProgressView()
                    } else if let baseline = model.progress.baselineDownloadSeconds {
                        Text(String(localized: "\(String(format: "%.2f", baseline)) 秒"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(model.isMeasuringBaseline)

            if model.isMeasuringBaseline, let startedAt = baselineStartedAt {
                elapsedRow(since: startedAt)
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "回線を絞る前の計測"),
                systemImage: "gauge.with.needle"
            )
        } footer: {
            Text("この画面を開くたびに計測値は破棄されます。Network Conditions を OFF にした状態で測ってください。")
        }
    }

    private var runSection: some View {
        Section {
            Button {
                runStartedAt = .now
                Task { await model.run(lesson) }
            } label: {
                ZStack {
                    Text("リクエストを送る")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    if runState.isRunning {
                        HStack {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
            .disabled(runState.isRunning)

            if runState.isRunning, let startedAt = runStartedAt {
                elapsedRow(since: startedAt)
            }
        } footer: {
            if runState.isRunning {
                Text(waitingHint)
            }
        }
    }

    /// 「見る」操作はレスポンスを変えないので、Proxyman でしか読めない値を答えてもらう。
    private func answerSection(_ prompt: AnswerPrompt) -> some View {
        Section {
            TextField(prompt.placeholder, text: answerBinding)
                .font(.system(.body, design: .monospaced))
                // 入れるのは英数字だけ。かな入力のままだと変換候補を挟むことになる。
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)

            Button {
                Task { await model.submitAnswer(for: lesson) }
            } label: {
                Text("答え合わせ")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canSubmitAnswer)
        } header: {
            LabSectionHeader(
                title: prompt.title,
                systemImage: "text.magnifyingglass"
            )
        } footer: {
            if runState.result == nil {
                Text(String(localized: "先に`リクエストを送る`を押してください。").instructionText)
            } else {
                Text(prompt.hint.instructionText)
            }
        }
    }

    private var answerBinding: Binding<String> {
        Binding(
            get: { model.answer(for: lesson.id) },
            set: { model.setAnswer($0, for: lesson.id) }
        )
    }

    private var canSubmitAnswer: Bool {
        guard runState.result != nil else { return false }
        return !model.answer(for: lesson.id)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    /// 待たされるレッスンでは、スピナーだけだと固まったのか進んでいるのか分からない。
    /// 経過秒数と、あきらめるまでの上限を出して「生きている」ことを見せる。
    private func elapsedRow(since startedAt: Date) -> some View {
        TimelineView(.periodic(from: startedAt, by: 0.5)) { context in
            LabeledContent("経過") {
                Text(
                    String(
                        localized: """
                            \(String(format: "%.1f", max(0, context.date.timeIntervalSince(startedAt)))) 秒 / \
                            最大 \(String(format: "%.0f", lesson.probe.timeout)) 秒
                            """
                    )
                )
                .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// なぜ待たされているのかは、レッスンによって理由が違う。
    private var waitingHint: String {
        switch lesson.id {
        case .filter:
            String(localized: "\(LabMarkers.filterTotalCount) 件をまとめて送っています。")
        case .breakpointRequest, .breakpointBody, .breakpointResponse:
            String(localized: "Proxyman が通信を止めています。Breakpoints ウィンドウで書き換えて Execute を押すまで待ち続けます。")
        case .networkCondition:
            String(localized: "1 MB をダウンロードしています。回線を絞っているぶん時間がかかります。そのままお待ちください。")
        default:
            String(localized: "応答を待っています。")
        }
    }

    private func verdictSection(_ verdict: Verdict) -> some View {
        Section {
            // 結論を 1 行で出し、対処はその下に 1 つずつ並べる。
            // まとめて 1 つの塊にすると、どこから手を付けるのか分からなくなる。
            Text(verdict.summary.instructionText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ResultStatus(verdict).textTint)
                .padding(.vertical, 2)

            ForEach(Array(verdict.details.enumerated()), id: \.offset) { _, line in
                Label {
                    Text(line.instructionText)
                } icon: {
                    Image(systemName: "arrow.right")
                }
                    .font(.callout)
                    .labelStyle(.titleAndIcon)
                    .padding(.vertical, 2)
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "判定"),
                systemImage: ResultStatus(verdict).systemImage,
                tint: ResultStatus(verdict).textTint,
                iconTint: ResultStatus(verdict).tint
            )
        }
    }

}

private struct MaterialSection: View {
    let material: Material
    @State private var didCopy = false

    var body: some View {
        Section {
            Text(material.purpose)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(material.content)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = material.content
                didCopy = true
            } label: {
                Label(
                    didCopy ? String(localized: "コピーしました") : String(localized: "\(material.kind.label) をコピー"),
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
        } header: {
            LabSectionHeader(
                title: material.title,
                systemImage: "doc.text"
            )
        }
    }
}
