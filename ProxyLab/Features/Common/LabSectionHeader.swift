//
//  LabSectionHeader.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

/// セクションの見出し。
///
/// 標準の見出しは小さいグレーの大文字で、本文との差が付きすぎて読み飛ばされる。
/// 本文と同じ色・同じ向きの文字にし、アイコンだけでセクションを見分けられるようにする。
struct LabSectionHeader: View {
    let title: String
    let systemImage: String
    /// 見出し文字の色。失敗を伝えるときだけ赤くする。既定は本文と同じ色。
    var tint: Color = .primary
    /// 記号の色。成功を緑で出したいときのように、文字と分けたいときだけ指定する。
    var iconTint: Color?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconTint ?? tint)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .textCase(nil)
    }
}
