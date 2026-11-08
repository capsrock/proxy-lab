//
//  Lesson.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// ユーザーが Proxyman 側にコピーして使う素材。
struct Material: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case json
        case javaScript
        /// ステータス行とヘッダを含む、レスポンスまるごと。
        case http

        var label: String {
            switch self {
            case .json: "JSON"
            case .javaScript: "JavaScript"
            case .http: String(localized: "レスポンス")
            }
        }
    }

    let title: String
    let kind: Kind
    /// この素材を何に使うのか。手順までスクロールを戻さなくても分かるようにする。
    let purpose: String
    let content: String
}

/// Proxyman の入力欄に貼り付ける値。
/// 手順の文章に URL を埋め込むと選択できずコピーできないので、値は必ずこちらに置く。
struct CopyableValue: Identifiable, Sendable, Equatable {
    /// Proxyman 側の欄の名前（"URL" / "Map From" など）。
    let label: String
    let value: String

    var id: String { "\(label)-\(value)" }
}

/// 手順 1 行。
///
/// 貼り付ける値は、必ずその値を使う手順に紐付ける。
/// 別のセクションにまとめると「下の値」がどれなのか読み手に探させることになる。
struct LessonStep: Identifiable, Sendable, Equatable {
    let text: String
    let value: CopyableValue?

    var id: String { text }

    init(_ text: String, value: CopyableValue? = nil) {
        self.text = text
        self.value = value
    }
}

/// レスポンスだけでは「やったかどうか」が分からないレッスンで、ユーザーに答えてもらう欄。
///
/// Proxyman を「見る」操作はレスポンスを一切変えない。
/// 見たかどうかを確かめる方法は、Proxyman でしか読めない値を答えてもらうことしかない。
struct AnswerPrompt: Sendable, Equatable {
    let title: String
    let placeholder: String
    /// 欄の下に出す補足。どこの値を入れるのかを、手順まで戻らずに思い出せるようにする。
    let hint: String
}

/// レッスン 1 件。判定はクロージャで持たせ、レッスンの追加を宣言 1 個で済ませる。
struct Lesson: Identifiable, Sendable {
    let id: LessonID
    let number: Int
    let title: String
    let feature: String
    let goal: String
    /// Proxyman 側でやる手順。貼り付ける値は該当の手順に紐付いている。
    let steps: [LessonStep]
    let material: Material?
    /// 判定に使う 1 本。
    let probe: Probe
    /// 判定には使わず、`probe` と一緒に流すだけのリクエスト。
    /// Proxyman の一覧によく似た行を並べ、絞り込みを実際に必要にする。
    let noise: [Probe]
    /// レスポンスに現れない操作を確かめるための答えの欄。要らないレッスンでは nil。
    let answer: AnswerPrompt?
    let verify: @Sendable (ProbeResult, VerificationContext) -> Verdict

    /// 手順に紐付いた値の一覧。
    var inputs: [CopyableValue] { steps.compactMap(\.value) }

    var displayNumber: String {
        String(format: "%02d", number)
    }

    init(
        id: LessonID,
        number: Int,
        title: String,
        feature: String,
        goal: String,
        steps: [LessonStep],
        material: Material? = nil,
        probe: Probe,
        noise: [Probe] = [],
        answer: AnswerPrompt? = nil,
        verify: @escaping @Sendable (ProbeResult, VerificationContext) -> Verdict
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.feature = feature
        self.goal = goal
        self.steps = steps
        self.material = material
        self.probe = probe
        self.noise = noise
        self.answer = answer
        self.verify = verify
    }
}
