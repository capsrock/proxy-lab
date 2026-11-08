//
//  SystemProxy.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation

/// この URL に対して実際にプロキシが使われるかを、システム設定から読む。
///
/// 証明書だけでは「Proxyman を経由していない」と
/// 「経由しているがこのドメインを復号していない（トンネルのみ）」を区別できない。
/// どちらも本物の証明書が返ってくるため。プロキシ設定を併せて見ることで切り分ける。
enum SystemProxy {

    /// 使われるプロキシを "ホスト:ポート" で返す。プロキシを通さない場合は nil。
    static func description(for url: URL) -> String? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return nil
        }
        let proxies = CFNetworkCopyProxiesForURL(url as CFURL, settings)
            .takeRetainedValue() as? [[String: Any]] ?? []

        for proxy in proxies {
            guard
                let type = proxy[kCFProxyTypeKey as String] as? String,
                type != (kCFProxyTypeNone as String),
                let host = proxy[kCFProxyHostNameKey as String] as? String
            else { continue }

            guard let port = proxy[kCFProxyPortNumberKey as String] as? Int else { return host }
            return "\(host):\(port)"
        }
        return nil
    }
}
