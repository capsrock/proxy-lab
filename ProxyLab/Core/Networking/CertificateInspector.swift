//
//  CertificateInspector.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/07.
//

import Foundation
import Security

/// サーバ証明書チェーンから「Proxyman に復号されているか」を判断する。
///
/// Proxyman は SSL Proxying を有効にしたホストに対して自前の CA で署名した証明書を差し込む。
/// つまりチェーンの Subject に Proxyman の名前が現れたら、中身が見えている状態。
enum CertificateInspector {

    /// この文字列が Subject に含まれていたら Proxyman の証明書とみなす。
    static let proxymanSignature = "proxyman"

    static func subjects(of trust: SecTrust) -> [String] {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return []
        }
        return chain.compactMap { SecCertificateCopySubjectSummary($0) as String? }
    }

    /// Subject 一覧の判定。SecTrust から切り離してあるので単体テストできる。
    static func isProxymanChain(_ subjects: [String]) -> Bool {
        subjects.contains { $0.lowercased().contains(proxymanSignature) }
    }
}
