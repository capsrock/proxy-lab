//
//  LabProgress.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 学習の進捗。値型のまま差し替えていくので、更新は必ず新しい値を返す。
struct LabProgress: Codable, Equatable, Sendable {
    let clearedLessons: Set<LessonID>
    /// 回線を絞る前に計測した素の所要時間。レッスン 09 の判定基準になる。
    let baselineDownloadSeconds: TimeInterval?
    /// セットアップ診断が「セットアップ完了」まで到達したか。
    ///
    /// 復号できるようにするところまでは準備であってレッスンではないので、
    /// クリア済みレッスンとは別に持つ。ここが false のあいだは、
    /// どのレッスンもルールを正しく組んでもレスポンスが変わらない。
    let isSetupComplete: Bool

    static let empty = LabProgress(
        clearedLessons: [],
        baselineDownloadSeconds: nil,
        isSetupComplete: false
    )

    func clearing(_ id: LessonID) -> LabProgress {
        LabProgress(
            clearedLessons: clearedLessons.union([id]),
            baselineDownloadSeconds: baselineDownloadSeconds,
            isSetupComplete: isSetupComplete
        )
    }

    func settingBaseline(_ seconds: TimeInterval) -> LabProgress {
        LabProgress(
            clearedLessons: clearedLessons,
            baselineDownloadSeconds: seconds,
            isSetupComplete: isSetupComplete
        )
    }

    func clearingBaseline() -> LabProgress {
        LabProgress(
            clearedLessons: clearedLessons,
            baselineDownloadSeconds: nil,
            isSetupComplete: isSetupComplete
        )
    }

    func completingSetup() -> LabProgress {
        LabProgress(
            clearedLessons: clearedLessons,
            baselineDownloadSeconds: baselineDownloadSeconds,
            isSetupComplete: true
        )
    }

    func isCleared(_ id: LessonID) -> Bool {
        clearedLessons.contains(id)
    }

    var completionRatio: Double {
        guard !LessonID.allCases.isEmpty else { return 0 }
        return Double(clearedLessons.count) / Double(LessonID.allCases.count)
    }
}
