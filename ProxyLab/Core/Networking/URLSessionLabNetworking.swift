//
//  URLSessionLabNetworking.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 実際に通信する実装。
///
/// キャッシュは全面的に無効化する。Map Local や Script でレスポンスを差し替えても
/// キャッシュが返ってきては学習にならないため。
struct URLSessionLabNetworking: LabNetworking {

    let host: LabHost

    init(host: LabHost = .publicAPIs) {
        self.host = host
    }

    func send(_ probe: Probe) async -> ProbeResult {
        let url = host.resolve(probe.endpoint)
        let proxy = SystemProxy.description(for: url)

        // セッションを使い回すと接続がプールされ、2 回目以降は TLS ハンドシェイクが起きない。
        // すると証明書チェーンを観測できず、SSL Proxying の判定が「取得できませんでした」に化ける。
        // ラボでは毎回まっさらな接続で測りたいので、リクエストごとに作って捨てる。
        let session = URLSession(configuration: Self.makeConfiguration())
        defer { session.finishTasksAndInvalidate() }

        let recorder = TrustRecorder()
        let clock = ContinuousClock()
        let start = clock.now

        do {
            let (data, response) = try await session.data(
                for: request(for: probe),
                delegate: recorder
            )
            return ProbeResult(
                host: url.host(),
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                headers: httpHeaders(from: response),
                body: data,
                duration: start.duration(to: clock.now).seconds,
                certificateSubjects: recorder.subjects,
                proxyInUse: proxy
            )
        } catch {
            LabLog.network.error("Probe が失敗しました: \(error.localizedDescription, privacy: .public)")
            // 失敗したときだけ確認する。機内モードや圏外を、プロキシの不調と取り違えないため。
            let reachable = await NetworkReachability.isAvailable()
            return ProbeResult(
                host: url.host(),
                duration: start.duration(to: clock.now).seconds,
                certificateSubjects: recorder.subjects,
                proxyInUse: proxy,
                networkAvailable: reachable,
                failure: labError(from: error)
            )
        }
    }

    private static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return configuration
    }

    private func request(for probe: Probe) -> URLRequest {
        var request = URLRequest(
            url: host.resolve(probe.endpoint),
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: probe.timeout
        )
        request.httpMethod = probe.body.httpMethod
        request.httpBody = probe.body.data
        if let contentType = probe.body.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        // ヘッダはレッスンが明示したものを最後に当てる。Content-Type を上書きしたい回が出ても通る。
        for (name, value) in probe.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    private func httpHeaders(from response: URLResponse) -> [String: String] {
        guard let http = response as? HTTPURLResponse else { return [:] }
        return http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            guard let name = pair.key as? String else { return }
            result[name] = String(describing: pair.value)
        }
    }

    private func labError(from error: Error) -> LabError {
        guard let urlError = error as? URLError else {
            return .transport(error.localizedDescription)
        }

        switch urlError.code {
        case .cannotConnectToHost, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed:
            return .connectionRefused(urlError.localizedDescription)
        case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .secureConnectionFailed:
            return .certificateUntrusted(urlError.localizedDescription)
        case .notConnectedToInternet:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .transport(urlError.localizedDescription)
        }
    }
}
