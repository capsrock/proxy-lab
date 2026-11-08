//
//  LabLog.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import OSLog

enum LabLog {
    private static let subsystem = "com.hideo.ProxyLab"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let progress = Logger(subsystem: subsystem, category: "progress")
}
