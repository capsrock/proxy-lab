//
//  CopyableValueSection.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

/// Proxyman に貼り付ける値 1 行。
/// 手順の文章に URL を混ぜると選択もコピーもできないので、値はこの形で手順の直下に出す。
struct CopyableValueRow: View {
    let value: CopyableValue

    @State private var didCopy = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value.value
            didCopy = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // 途中で省略されると、何を貼るのか結局分からない。必ず全体を折り返して見せる。
                    Text(value.value)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(didCopy ? String(localized: "コピー済") : String(localized: "コピー"), systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(didCopy ? Color.green : Color.accentColor)
                    .font(.callout)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
