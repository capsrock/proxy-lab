//
//  NetworkReachability.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation
import Network

/// いま端末がネットワークに出られるか。
///
/// 機内モードや圏外でも、プロキシ設定は端末に残ったままになる。
/// エラーの種類だけで切り分けると「プロキシに繋がりません → Proxyman を確認して」と案内してしまい、
/// 実際は Mac を触っても直らない。先にここを見て、端末側の問題を切り離す。
enum NetworkReachability {

    /// 一度だけ resume するための箱。`pathUpdateHandler` は同じキューで直列に呼ばれるので、
    /// この中の読み書きは競合しない。
    private final class Once: @unchecked Sendable {
        private var done = false
        func run(_ body: () -> Void) {
            guard !done else { return }
            done = true
            body()
        }
    }

    /// 最初の経路情報が届くまで待って返す。届かなければ「出られる」とみなす。
    /// 判定を止めるより、後続のエラー内容で切り分けた方が害が少ない。
    static func isAvailable(timeout: Duration = .milliseconds(300)) async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.hideo.ProxyLab.reachability")

        let status: Bool? = await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    let once = Once()
                    monitor.pathUpdateHandler = { path in
                        once.run { continuation.resume(returning: path.status == .satisfied) }
                    }
                    monitor.start(queue: queue)
                }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        monitor.cancel()
        return status ?? true
    }
}
