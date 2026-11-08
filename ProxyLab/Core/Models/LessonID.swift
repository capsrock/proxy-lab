//
//  LessonID.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// レッスンの安定した識別子。永続化されるので rawValue は変更しない。
///
/// 復号できるようにするところまでは「レッスン」ではなく準備なので、
/// レッスンには含めない。セットアップ診断が受け持つ。
enum LessonID: String, CaseIterable, Codable, Sendable {
    case filter = "01-filter"
    case mapLocal = "02-map-local"
    case breakpointRequest = "03-breakpoint-request"
    case breakpointBody = "04-breakpoint-body"
    case breakpointResponse = "05-breakpoint-response"
    case mapRemote = "06-map-remote"
    case scripting = "07-scripting"
    case blockList = "08-block-list"
    /// 最後に置く。回線を絞ること自体は Network Link Conditioner でもできて、
    /// Proxyman でなければできない話ではない。
    case networkCondition = "09-network-condition"
}
