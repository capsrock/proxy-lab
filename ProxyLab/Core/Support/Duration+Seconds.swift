//
//  Duration+Seconds.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation

extension Duration {
    /// 秒数に変換する。所要時間の表示と、回線速度の比較に使う。
    var seconds: TimeInterval {
        let (wholeSeconds, attoseconds) = components
        return TimeInterval(wholeSeconds) + TimeInterval(attoseconds) / 1e18
    }
}
