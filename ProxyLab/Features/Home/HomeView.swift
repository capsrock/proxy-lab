//
//  HomeView.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

struct HomeView: View {
    @Environment(LabModel.self) private var model
    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                progressSection
                doctorSection
                lessonsSection
                settingsSection
            }
            .navigationTitle("ProxyLab")
            .listStyle(.insetGrouped)
            // リスト自身の地を消して、後ろのオーロラを見せる。
            // 各セルの地は残るので、文字の読みやすさは変わらない。
            .scrollContentBackground(.hidden)
            .background {
                AuroraBackground()
            }
        }
    }

    private var progressSection: some View {
        Section {
            HStack(spacing: 16) {
                ProgressRing(ratio: model.progress.completionRatio)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.progress.clearedLessons.count) / \(LessonID.allCases.count) クリア")
                        .font(.headline)
                    Text("各レッスンを完了すると、ステータスが更新されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var doctorSection: some View {
        Section {
            NavigationLink {
                SetupDoctorView()
            } label: {
                Label("セットアップ診断", systemImage: "stethoscope")
            }

        } header: {
            LabSectionHeader(
                title: String(localized: "まず、ここから"),
                systemImage: "flag"
            )
        } footer: {
            Text("""
                証明書をインストールして、復号できるように設定する必要があります。
                シミュレータと実機では手順が違います。環境ごとにセットアップ診断作業を行ってください。
                """)
        }
    }

    private var lessonsSection: some View {
        Section {
            ForEach(LessonCatalog.all) { lesson in
                NavigationLink {
                    LessonDetailView(lesson: lesson)
                } label: {
                    LessonRow(
                        lesson: lesson,
                        isCleared: model.progress.isCleared(lesson.id)
                    )
                }
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "レッスン"),
                systemImage: "list.bullet.rectangle"
            )
        } footer: {
            if !model.isSetupComplete {
                Text(String(localized: "まだ準備が済んでいません。先に`セットアップ診断`を`セットアップ完了`まで進めてください。手順を読むだけなら、レッスンはいつでも開けます。").instructionText)
            }
        }
    }

    private var settingsSection: some View {
        Section {
            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Text("進捗をリセット")
                    .frame(maxWidth: .infinity)
            }
            .confirmationDialog(
                String(localized: "クリア状況と baseline の計測値を消します。"),
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("リセットする", role: .destructive) {
                    Task { await model.resetProgress() }
                }
                Button("やめる", role: .cancel) {}
            }
        }
    }
}

private struct LessonRow: View {
    let lesson: Lesson
    let isCleared: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(lesson.displayNumber)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                Text(lesson.feature)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: statusIcon)
                .foregroundStyle(statusTint)
        }
        .padding(.vertical, 2)
    }

    private var statusIcon: String {
        if isCleared { return "checkmark.circle.fill" }
        return "circle"
    }

    private var statusTint: AnyShapeStyle {
        if isCleared { return AnyShapeStyle(.green) }
        return AnyShapeStyle(.quaternary)
    }
}

private struct ProgressRing: View {
    let ratio: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ratio * 100))%")
                .font(.caption2.bold())
                .monospacedDigit()
        }
        .animation(.easeOut, value: ratio)
    }
}

#Preview {
    HomeView()
        .environment(LabModel(networking: StubLabNetworking(result: ProbeResult())))
}
