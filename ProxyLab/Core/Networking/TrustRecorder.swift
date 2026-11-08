//
//  TrustRecorder.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// リクエスト 1 本ごとに使い捨てる delegate。
/// TLS ハンドシェイク時のサーバ証明書チェーンを記録する。
///
/// タスクごとに別インスタンスを渡すので、タスク ID による振り分けは不要。
final class TrustRecorder: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    private let lock = NSLock()
    private var recordedSubjects: [String] = []

    var subjects: [String] {
        lock.withLock { recordedSubjects }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }

        lock.withLock { recordedSubjects = CertificateInspector.subjects(of: trust) }
        return (.performDefaultHandling, nil)
    }
}
