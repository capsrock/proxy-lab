//
//  Verdict.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// レッスンの判定結果。
/// `notYet` には「何が期待と違ったか」を必ず入れる。ここが学習の手がかりになる。
enum Verdict: Equatable, Sendable {
    case cleared(detail: String)
    case notYet(reason: String)
    case failed(reason: String)

    var isCleared: Bool {
        if case .cleared = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .cleared(let detail): detail
        case .notYet(let reason): reason
        case .failed(let reason): reason
        }
    }

    /// 1 行目。何が起きたかだけを短く言う。
    ///
    /// 判定文はどれも「1 行目に結論、2 行目以降に対処」で書いてある。
    /// 全部まとめて出すと読み飛ばされるので、出す場所で切り分けられるようにしておく。
    var summary: String {
        lines.first ?? message
    }

    /// 2 行目以降。どうすればよいかの具体。
    var details: [String] {
        Array(lines.dropFirst())
    }

    private var lines: [String] {
        message
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// 判定に必要な、レスポンス以外の文脈。
struct VerificationContext: Sendable, Equatable {
    /// 絞る前に計測しておいた素の所要時間。
    let baselineDownloadSeconds: TimeInterval?
    /// レスポンスに現れない操作を確かめるために、ユーザーが入力した答え。
    let answer: String

    init(baselineDownloadSeconds: TimeInterval? = nil, answer: String = "") {
        self.baselineDownloadSeconds = baselineDownloadSeconds
        self.answer = answer
    }

    static let empty = VerificationContext()
}
