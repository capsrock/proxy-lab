//
//  RawResponseSection.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

/// 生のレスポンスを最初から表示する。判定結果の根拠をすぐ確認できるようにする。
struct RawResponseSection: View {
    let result: ProbeResult
    @State private var isExpanded = true

    var body: some View {
        Section {
            DisclosureGroup("中身を見る", isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("ステータス", value: result.statusCode.map(String.init) ?? "—")
                    LabeledContent("所要時間", value: String(localized: "\(String(format: "%.2f", result.duration)) 秒"))

                    if !result.certificateSubjects.isEmpty {
                        LabeledContent(
                            String(localized: "証明書"),
                            value: result.certificateSubjects.joined(separator: " / ")
                        )
                    }

                    if let failure = result.failure {
                        LabeledContent("エラー", value: failure.message)
                    }

                    if !result.body.isEmpty {
                        // 横だけスクロールさせる。高さを固定すると、中身が 2 行でも
                        // その高さのまま空白が居座る（ScrollView は与えた高さいっぱいに広がる）。
                        ScrollView(.horizontal) {
                            Text(result.displayBody)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize()
                                .padding(8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .font(.caption)
                .padding(.vertical, 4)
            }
        } header: {
            LabSectionHeader(
                title: String(localized: "生のレスポンス"),
                systemImage: "chevron.left.forwardslash.chevron.right"
            )
        }
    }
}
