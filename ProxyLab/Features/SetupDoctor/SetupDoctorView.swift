//
//  SetupDoctorView.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

struct SetupDoctorView: View {
    @Environment(LabModel.self) private var model
    @State private var showDiagnosisAlert = false
    @State private var diagnosisAlertMessage = ""
    @State private var diagnosisAlertStatus: ResultStatus = .failed

    var body: some View {
        List {
            Section {
                Text("""
                    アプリからのリクエスト送信時に、サーバ証明書の発行者を確認して、 \
                    Proxyman と正しく通信しているかを確認します。
                    """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            deviceGuideNavigationSection
        }
        .navigationTitle("セットアップ診断")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isRunning: Bool {
        if case .running = model.doctorState { return true }
        return false
    }

    private var deviceGuideNavigationSection: some View {
        Section {
            NavigationLink {
                guidePage(title: String(localized: "iPhone シミュレータの手順")) {
                    simulatorGuideSection
                }
            } label: {
                Label("iPhone シミュレータの手順", systemImage: "desktopcomputer")
            }

            NavigationLink {
                // 後片付けの案内は診断ボタンより後ろに置く。
                // 手順の途中に出すと、まだ診断していない人に先に「戻して」と言うことになる。
                guidePage(
                    title: String(localized: "実機の手順"),
                    noteAfterAction: String(localized: "確認が終わったら、iPhone の `HTTP プロキシ` を `オフ` に戻してください。")
                ) {
                    physicalDeviceGuideSection
                }
            } label: {
                Label("実機の手順", systemImage: "iphone")
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "実行環境ごとの手順"),
                systemImage: "arrow.triangle.branch"
            )
        } footer: {
            Text("実行先によって必要な設定が違います。実機は iPhone 側の HTTP プロキシ設定が要りますが、シミュレータは要りません。")
        }
    }

    private var simulatorGuideSection: some View {
        Section {
            guideRows([
                String(localized: "Xcode の実行先に iPhone Simulator を選び、`Run`（⌘R）でアプリを起動する。"),
                String(localized: "Mac で Proxyman を起動する。"),
                SetupInstruction.installCertificateOnSimulator,
                SetupInstruction.enableSSLProxying,
            ])

            copyableDomainRow

            guideRows([SetupInstruction.confirmWithDoctor], startingAt: 5)
        }
    }

    /// 貼り付ける値は、それを使う手順の直下に置く。
    /// 手順の文中に書いたドメインは折り返し対策で加工してあり、選んでもそのままでは貼れない。
    private var copyableDomainRow: some View {
        CopyableValueRow(value: SetupInstruction.sslProxyingDomain)
            .padding(.leading, 28)
    }

    /// 見出しは付けない。画面のタイトルが「iPhone シミュレータの手順」「実機の手順」なので、
    /// その下にもう一度「〜で実行する場合」と置くと同じことを二度言うことになる。
    private func guidePage<GuideContent: View>(
        title: String,
        noteAfterAction: String? = nil,
        @ViewBuilder guide: @escaping () -> GuideContent
    ) -> some View {
        ScrollViewReader { proxy in
            List {
                guide()

                diagnosisActionSection(note: noteAfterAction)

                if case .finished(let diagnosis, let result) = model.doctorState {
                    resultSection(diagnosis)
                        .id("diagnosis-result")
                    RawResponseSection(result: result)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                model.clearDoctorResult()
            }
            .onChange(of: model.doctorState) { _, newState in
                guard case .finished(let diagnosis, _) = newState else { return }
                diagnosisAlertStatus = diagnosis.resultStatus
                diagnosisAlertMessage = diagnosis.headline
                showDiagnosisAlert = true

                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("diagnosis-result", anchor: .top)
                }
            }
            .overlay {
                if showDiagnosisAlert {
                    ResultOverlay(
                        status: diagnosisAlertStatus,
                        message: diagnosisAlertMessage
                    ) {
                        showDiagnosisAlert = false
                    }
                }
            }
        }
    }

    private func diagnosisActionSection(note: String?) -> some View {
        Section {
            Button {
                Task { await model.runDoctor() }
            } label: {
                ZStack {
                    Text("診断する")
                    if case .running = model.doctorState {
                        HStack {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isRunning)
        } footer: {
            if let note {
                Text(note.instructionText)
            }
        }
    }

    private var physicalDeviceGuideSection: some View {
        Section {
            // iPhone 版 Proxyman は VPN として端末内で通信を捕まえる。
            // 入れたままだと Mac に届く前に横取りされ、Mac の一覧に 1 件も出ない。
            // 証明書はどちらも `Proxyman CA` なので、診断では Mac 版と区別が付かない。
            guideRows([
                String(localized: "iPhone の `設定` → `VPN` が `接続済み` なら、オフにする必要があります。iPhone 版 Proxyman がインストールされていて、`VPN` がオンになっていると、Mac 版にリクエストが送信されません。"),
                String(localized: "iPhone と Mac を同じ Wi-Fi に接続する。"),
                String(localized: "iPhone の `設定` → `Wi-Fi` → 接続中のネットワークの ⓘ → `HTTP プロキシ` で `手動` を選ぶ。"),
            ])

            guideRows([
                String(localized: "iPhone の同じ画面で、`サーバ` の欄に Mac の IP アドレス、`ポート` の欄に 9090 を入れる。"),
            ], startingAt: 4)

            Text("＊ Mac の IP アドレスは `システム設定` → `Wi-Fi` → 接続中のネットワークの `詳細…` → `TCP/IP` → `IP アドレス` で確認できます。")
                .font(.callout)
                .foregroundStyle(.secondary)

            // 必要な部分（IP アドレスの行）だけに切り取ってあるので、
            // この幅のままで読める。拡大の仕組みは要らない。
            Image(.macIPGuide)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Mac のシステム設定で IP アドレスが表示されている場所")

            guideRows([
                SetupInstruction.installCertificateOnDevice,
                SetupInstruction.trustRootCertificate,
                SetupInstruction.enableSSLProxying,
            ], startingAt: 5)

            copyableDomainRow

            guideRows([SetupInstruction.confirmWithDoctor], startingAt: 8)
        }
    }

    private func guideRows(_ steps: [String], startingAt: Int = 1) -> some View {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(index + startingAt)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)

                Text(step.instructionText)
                    .font(.body)
            }
            .padding(.vertical, 2)
        }
    }

    private func resultSection(_ diagnosis: Diagnosis) -> some View {
        Section {
            // 結論はここに残す。オーバーレイは閉じられるし、成功時は文言を出さないので、
            // ここに無いと「復号できています」がどこにも出ないことになる。
            Text(diagnosis.headline.instructionText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(diagnosis.resultStatus.textTint)
                .padding(.vertical, 2)

            if let issuers = diagnosis.issuerSummary {
                LabeledContent("証明書の発行者", value: issuers)
                    .font(.caption)
            }

            ForEach(Array(diagnosis.advice.enumerated()), id: \.offset) { _, line in
                Label {
                    Text(line.instructionText)
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .font(.callout)
                .labelStyle(.titleAndIcon)
            }
        } header: {
            // 記号はレッスンの判定と共通にする。⚠ は「注意」であって「失敗」ではないし、
            // 同じ結果を画面ごとに違う記号で出す理由もない。
            LabSectionHeader(
                title: String(localized: "結果"),
                systemImage: diagnosis.resultStatus.systemImage,
                tint: diagnosis.resultStatus.textTint,
                iconTint: diagnosis.resultStatus.tint
            )
        }
    }

}

#Preview {
    NavigationStack {
        SetupDoctorView()
            .environment(LabModel(networking: StubLabNetworking(result: ProbeResult())))
    }
}
