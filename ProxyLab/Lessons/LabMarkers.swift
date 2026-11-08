//
//  LabMarkers.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 「ユーザーが Proxyman を操作した」ことを示す目印。
/// 本物のサーバは絶対に返さない値にしておくことで、判定が誤検知しない。
enum LabMarkers {
    /// レッスンを URL のクエリで見分けるためのキー。
    /// 同じ /get を叩くレッスンが複数あるので、Proxyman 側のルールが混ざらないように分ける。
    static let lessonKey = "lesson"

    // 01 Filter

    static let filterLesson = "filter"
    /// 同じ /get を 12 件並べたときに、URL のここだけが違う。
    static let filterItemKey = "item"
    /// 探し当ててほしい 1 件。残り 11 件は 01〜11 の通し番号。
    static let filterTargetItem = "code"
    /// 目的の 1 件にだけ載せるヘッダ。エコーサービスがそのまま返すので、Proxyman で読める。
    static let codeHeader = "X-Lab-Code"
    /// Proxyman から読み取ってもらう値。
    /// **アプリの画面には絶対に出さない。** 出した時点で「見る」練習が成立しない。
    static let filterCode = "K7QM"
    /// 紛れとして一緒に流すリクエストの数。
    static let filterNoiseCount = 11
    /// 一度に飛ぶ本数。手順の文章と実際の本数がずれないよう、ここから引く。
    static let filterTotalCount = filterNoiseCount + 1

    // 02 Map Local
    static let mapLocalKey = "proxymanLab"
    static let mapLocalValue = "map-local"

    // 03 Breakpoint (Request)
    static let tokenHeader = "X-Lab-Token"
    static let tokenPending = "PENDING"
    static let tokenGranted = "GRANTED"

    // 04 Breakpoint (Request Body)

    /// 送る JSON の中で書き換えてもらうキー。
    /// 隣にもう 1 つキーを置いて、本文の中から目的の行を探す必要がある形にする。
    static let planKey = "plan"
    static let planBefore = "free"
    static let planAfter = "pro"
    static let planUserKey = "userId"
    static let planUserID = 1

    // 05 Breakpoint (Response)
    static let brokenStatus = 500
    static let repairedStatus = 200

    // 06 Map Remote
    static let environmentKey = "env"
    static let productionEnvironment = "production"
    static let stagingEnvironment = "staging"

    /// エコーされた URL の中で環境を見分ける文字列。
    static func environmentQuery(_ environment: String) -> String {
        "\(environmentKey)=\(environment)"
    }

    // 07 Scripting
    static let injectedPostID = 9999
    /// スクリプトがレスポンスに生やす配列のキー。
    static let injectedArrayKey = "items"
}

/// 判定に使うしきい値。
enum LabThresholds {
    /// baseline の何倍まで遅くなったら「絞れた」とみなすか。
    static let throttleRatio: Double = 3.0
    /// baseline がこれより短いと比率が暴れるので、計測やり直しを促す。
    static let minimumBaselineSeconds: TimeInterval = 0.05
}
