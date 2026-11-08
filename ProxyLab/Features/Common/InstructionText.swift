//
//  InstructionText.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

extension String {

    /// 手順や案内の 1 行を、表示用の文字列に変える。
    ///
    /// 画面に出ている文字列（メニュー項目・ボタン・欄・トグルの名前）は、
    /// ソース上でバッククォートで囲んで書く。ここで太字に変えて本文と区別する。
    ///
    ///     "一覧で `Enable Rule` が ON になっていることを確認する。"
    ///
    /// 等幅にはしない。等幅は貼り付ける値（`CopyableValueRow`）で使っており、
    /// 「入力する値」と「画面の項目名」が同じ見た目になってしまう。
    ///
    /// 太さだけを変えるので、呼び出し側が指定した文字サイズはそのまま残る。
    var instructionText: AttributedString {
        guard var text = try? AttributedString(
            markdown: self,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            // 記法として壊れていても、文章は読めた方がよい。
            return AttributedString(self)
        }

        for run in text.runs {
            guard run.inlinePresentationIntent?.contains(.code) == true else { continue }
            text[run.range].inlinePresentationIntent = .stronglyEmphasized
        }
        return text
    }
}
