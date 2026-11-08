//
//  ResultOverlay.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

/// 実行結果の見せ方。
///
/// 「まだ」と「失敗」は分ける。手順の途中で押しただけの状態にまで ✗ を出すと、
/// 何も壊れていないのに操作を間違えたと思わせる。
/// レッスン 01 は 12 件を送り終えた時点がまさにこれで、
/// そこから Proxyman を触ってもらうのに「Failed」と言うのは嘘になる。
enum ResultStatus: Sendable {
    case cleared
    /// 期待した変化はまだ起きていない。通信そのものは通っている。
    case notYet
    /// 通信が成立していない、または公開 API 側の問題。
    case failed

    var title: String {
        switch self {
        case .cleared: "Success!"
        case .notYet: "Not yet"
        case .failed: "Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .cleared: "checkmark.circle.fill"
        case .notYet: "arrow.right.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    /// 記号の色。
    var tint: Color {
        switch self {
        case .cleared: .green
        case .notYet: .orange
        case .failed: .red
        }
    }

    /// 結論の文字色。
    ///
    /// 色は記号だけで伝える。文字まで着色すると、読ませたい文が背景から浮いて読みにくい。
    var textTint: Color { .primary }

    /// クリアしたときだけ、理由を読む必要がない。
    var showsMessage: Bool { self != .cleared }
}

extension ResultStatus {
    init(_ verdict: Verdict) {
        switch verdict {
        case .cleared: self = .cleared
        case .notYet: self = .notYet
        case .failed: self = .failed
        }
    }
}

/// 実行結果を画面中央に大きく出すオーバーレイ。
///
/// レッスンの判定とセットアップ診断は「押した結果どうだったか」という同じ問いに答えるので、
/// 見え方も同じにする。標準の `alert` を使わないのは、成功したときに大きな ✓ を出したいため。
///
/// フェードの状態はこの中で持つ。呼び出し側は出すか出さないかだけを決める。
struct ResultOverlay: View {
    let status: ResultStatus
    /// クリア以外のときに出す、何が期待と違ったかの説明。
    let message: String
    let onDismiss: () -> Void

    @State private var opacity: Double = 0

    private static let fadeInSeconds = 0.2
    private static let fadeOutSeconds = 0.3

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: status.systemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(status.tint)

                Text(status.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(status.textTint)
                    .padding(.bottom, 10)

                if status.showsMessage {
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }

                Button(action: dismiss) {
                    Text("OK")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(opacity)
        .zIndex(10)
        .onAppear {
            withAnimation(.easeIn(duration: Self.fadeInSeconds)) { opacity = 1 }
        }
    }

    /// 消えきってから呼び出し側に伝える。先に伝えるとフェードアウトが見えない。
    private func dismiss() {
        withAnimation(.easeOut(duration: Self.fadeOutSeconds)) { opacity = 0 }
        Task {
            try? await Task.sleep(for: .seconds(Self.fadeOutSeconds))
            onDismiss()
        }
    }
}

#Preview("クリア") {
    ResultOverlay(status: .cleared, message: "", onDismiss: {})
}

#Preview("まだ") {
    ResultOverlay(
        status: .notYet,
        message: "ヘッダは PENDING のまま届きました。",
        onDismiss: {}
    )
}

#Preview("失敗") {
    ResultOverlay(
        status: .failed,
        message: "インターネットに接続されていません",
        onDismiss: {}
    )
}
