//
//  FileProgressStore.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// 進捗を JSON ファイルに保存する。
/// 読み込みに失敗しても学習は続けられるべきなので、空の進捗にフォールバックしつつ必ず記録は残す。
actor FileProgressStore: ProgressStoring {

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    /// パスを文字列に変換すると `URL.path()` が percent-encode してしまい、
    /// "Application Support" のようなスペース混じりのディレクトリで存在判定が壊れる。
    /// URL のまま読み、「ファイルが無い」だけを初回起動として扱う。
    func load() -> LabProgress {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(LabProgress.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .empty
        } catch {
            LabLog.progress.error(
                "進捗の読み込みに失敗したため空から開始します: \(error.localizedDescription, privacy: .public)"
            )
            return .empty
        }
    }

    func save(_ progress: LabProgress) {
        do {
            let data = try JSONEncoder().encode(progress)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            LabLog.progress.error(
                "進捗の保存に失敗しました: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "lab-progress.json")
    }
}
