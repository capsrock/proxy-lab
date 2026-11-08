//
//  LessonCatalog.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import Foundation

/// レッスンの定義。追加はここに 1 要素足すだけで済む。
///
/// 手順は Proxyman の実際のメニュー構成に合わせてある。
/// 貼り付ける値は、それを使う手順そのものに紐付ける。別の場所にまとめると読み手に探させることになる。
/// エンドポイントは全レッスンで同じホストに揃えてある。SSL Proxying List への登録を 1 回で済ませるため。
enum LessonCatalog {

    static let all: [Lesson] = [
        filter,
        mapLocal,
        breakpointRequest,
        breakpointBody,
        breakpointResponse,
        mapRemote,
        scripting,
        blockList,
        networkCondition,
    ]

    static func lesson(_ id: LessonID) -> Lesson? {
        all.first { $0.id == id }
    }

    /// Proxyman のメニューバーは画面最上部にある。ウィンドウの中ではない。
    private static let menuBar = String(localized: "Proxyman のメニューバー（画面最上部）")

    private static let host = LabHost.publicAPIs
    private static func url(_ endpoint: LabEndpoint) -> String {
        host.resolve(endpoint).absoluteString
    }

    /// Proxyman の Matching Rule は既定で Wildcard として解釈される。
    /// クエリ付き URL をそのまま表示すると `?` が「任意の1文字」になり、
    /// 実際のリクエストに一致しないため、クエリを含むルールは Wildcard 形式で渡す。
    private static func matchingURL(_ endpoint: LabEndpoint) -> String {
        switch endpoint {
        case .echoForLesson(let lesson):
            "\(url(.echo))*\(LabMarkers.lessonKey)=\(lesson)*"
        case .largePayload:
            "\(host.echoService.appending(path: "bytes").appending(path: "1").appending(path: "mb"))*\(LabMarkers.lessonKey)=speed*"
        default:
            url(endpoint)
        }
    }

    // MARK: 01

    /// 「見る」操作はレスポンスを変えないので、他のレッスンのやり方では判定できない。
    /// よく似たリクエストを 12 件まとめて流し、絞り込まないと読めない値を答えてもらう。
    private static let filter = Lesson(
        id: .filter,
        number: 1,
        title: String(localized: "目的のリクエストを一覧から探す"),
        feature: "Filter",
        goal: String(localized: "似たようなAPIの一覧が並ぶ中から、特定のAPIを探して中身を調べる練習をします。"),
        steps: [
            LessonStep(
                String(localized: "アプリで`リクエストを送る`を押す。よく似たリクエストが \(LabMarkers.filterTotalCount) 件まとめて飛ぶ。")
            ),
            LessonStep(
                String(localized: "Mac の Proxyman に切り替え、左のサイドバーの `Domains` から postman-echo.com を選ぶ。一覧がこのドメインの通信だけになる。")
            ),
            LessonStep(
                String(localized: "一覧の上に、`URL` `Contains` と並んだ絞り込みの行がある。`Contains` の右の欄にこの値を入れる。このレッスンの \(LabMarkers.filterTotalCount) 件だけが残る。"),
                value: CopyableValue(
                    label: String(localized: "絞り込みの欄（まず \(LabMarkers.filterTotalCount) 件に絞る）"),
                    value: "\(LabMarkers.lessonKey)=\(LabMarkers.filterLesson)"
                )
            ),
            LessonStep(
                String(localized: "同じ欄をこの値に書き換える。残るのは 1 件だけになる。\(LabMarkers.filterTotalCount) 件はどれも同じ `/get` なので、一覧の見た目では区別が付かない。違うのは URL の後ろだけ。"),
                value: CopyableValue(
                    label: String(localized: "絞り込みの欄（1 件に絞る）"),
                    value: "\(LabMarkers.filterItemKey)=\(LabMarkers.filterTargetItem)"
                )
            ),
            LessonStep(
                String(localized: "残った 1 件を選び、右の `Response` で `Body` を開く。返ってきた JSON の `headers` の中に `\(LabMarkers.codeHeader.lowercased())` があり、英数字 4 文字が入っている。")
            ),
            LessonStep(String(localized: "その 4 文字を、下の`答え合わせ`の欄に入れる。")),
        ],
        probe: Probe(
            endpoint: .echoForFilterItem(LabMarkers.filterTargetItem),
            headers: [LabMarkers.codeHeader: LabMarkers.filterCode]
        ),
        noise: (1...LabMarkers.filterNoiseCount).map { number in
            Probe(endpoint: .echoForFilterItem(String(format: "%02d", number)))
        },
        answer: AnswerPrompt(
            title: String(localized: "答え合わせ"),
            placeholder: String(localized: "英数字 4 文字"),
            hint: String(localized: "Proxyman で読み取った `\(LabMarkers.codeHeader.lowercased())` の値を入れてください。送り直す必要はありません。")
        ),
        verify: Verifiers.filter
    )

    // MARK: 02

    private static let mapLocal = Lesson(
        id: .mapLocal,
        number: 2,
        title: String(localized: "レスポンスをローカルファイルで書き換える"),
        feature: "Map Local",
        goal: String(localized: "リクエストをサーバまで到達させずに、Mac に置いた JSON ファイルの中身をレスポンスとして返します。バックエンドが未完成でも、返ってくる中身さえ決まっていれば画面を作り込むことができます。"),
        steps: [
            LessonStep(String(localized: "下の`差し替える中身`をコピーし、Mac に map-local.json という名前で保存する。")),
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Map Local…` を開く。")),
            LessonStep(String(localized: "⌘N を押して新しいエントリを追加する。")),
            LessonStep(
                String(localized: "Matching Rule の種類を Wildcard にし、URL の欄にこの値を入れる。"),
                value: CopyableValue(label: String(localized: "URL（Wildcard）"), value: matchingURL(.echoForLesson("map-local")))
            ),
            LessonStep(String(localized: "`Map To` の欄で `Enable Local File` を選ぶ。")),
            LessonStep(String(localized: "`File` の `Select Local File` を押し、保存した map-local.json を選ぶ。")),
            LessonStep(String(localized: "`Save` を押す。")),
            LessonStep(String(localized: "一覧で `Enable Rule` と `Enable Map Local Tool` が ON になっていることを確認する。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押す。")),
        ],
        material: Material(
            title: String(localized: "差し替える中身"),
            kind: .json,
            purpose: String(localized: "JSON本文を map-local.json として保存し、File の Select Local File で選ぶ。Proxyman がこのJSONをレスポンス本文として返す。"),
            content: String(localized: """
                {
                  "\(LabMarkers.mapLocalKey)": "\(LabMarkers.mapLocalValue)",
                  "id": 1,
                  "title": "ローカルファイルから返しています",
                  "body": "サーバが無くても画面は作れる"
                }
                """)
        ),
        probe: Probe(endpoint: .echoForLesson("map-local")),
        verify: Verifiers.mapLocal
    )

    // MARK: 03

    private static let breakpointRequest = Lesson(
        id: .breakpointRequest,
        number: 3,
        title: String(localized: "送信中のリクエストヘッダを書き換える"),
        feature: "Breakpoint (Request)",
        goal: String(localized: "アプリを修正せずに、送信するヘッダを書き換えます。認証トークンやフラグを、別の値に書き換えて試すことができます。"),
        steps: [
            LessonStep(
                String(localized: "\(menuBar)で Tools → Breakpoint → Rules… を開く。Breakpoint はサブメニューで、その中の Rules… が設定画面。")
            ),
            LessonStep(String(localized: "⌘N を押して新しいルールを追加する。")),
            LessonStep(
                String(localized: "Matching Rule の種類を Wildcard にし、この値を入れる。"),
                value: CopyableValue(
                    label: String(localized: "Matching Rule（Wildcard）"),
                    value: matchingURL(.echoForLesson("breakpoint"))
                )
            ),
            LessonStep(String(localized: "`Breakpoint` で `Request` にチェックを入れる。`Response` のチェックは外しておく。")),
            LessonStep(String(localized: "`Done` を押す。この画面のボタンは `Save` ではなく `Done`。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押すと、Proxyman が送信を止めて `Breakpoints` のウィンドウが開く。")),
            LessonStep(
                String(localized: "Proxyman の Headers タブで \(LabMarkers.tokenHeader) を探し、\(LabMarkers.tokenPending) をこの値（\(LabMarkers.tokenGranted)）に実際に書き換える。下のボタンが緑のチェックに変わるのはこのアプリでのコピー済み表示で、Proxyman 側の書き換えが済んだという意味ではない。"),
                value: CopyableValue(
                    label: String(localized: "\(LabMarkers.tokenHeader) の新しい値"),
                    value: LabMarkers.tokenGranted
                )
            ),
            LessonStep(String(localized: "Proxyman 上の値が \(LabMarkers.tokenGranted) になったことを確認して、`Execute` を押して送信を再開する。")),
        ],
        material: nil,
        probe: Probe(
            endpoint: .echoForLesson("breakpoint"),
            headers: [LabMarkers.tokenHeader: LabMarkers.tokenPending],
            timeout: 300
        ),
        verify: Verifiers.breakpointRequest
    )

    // MARK: 04

    /// 03 と同じ Breakpoint だが、触るのはヘッダではなくボディ。
    /// 実務でいちばん多いのはこちら。POST の JSON を差し替えて、
    /// サーバも画面も直さずに「その状態のアプリ」を見る。
    private static let breakpointBody = Lesson(
        id: .breakpointBody,
        number: 4,
        title: String(localized: "送信中のリクエストボディを書き換える"),
        feature: "Breakpoint (Request Body)",
        goal: String(localized: "アプリを修正せずに、送信するボディを書き換えます。課金プランや権限を、別の値に書き換えて試すことができます。"),
        steps: [
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Breakpoint` → `Rules…` を開く。")),
            LessonStep(String(localized: "⌘N を押して新しいルールを追加する。03 とは URL が違うので、別のルールとして足す。")),
            LessonStep(
                String(localized: "Matching Rule の欄に、この値を入れる。"),
                value: CopyableValue(label: "Matching Rule", value: url(.echoBody))
            ),
            LessonStep(String(localized: "`Breakpoint` で `Request` にチェックを入れる。`Response` のチェックは外しておく。")),
            LessonStep(String(localized: "`Done` を押す。")),
            LessonStep(
                String(localized: "アプリに戻って`リクエストを送る`を押すと、Proxyman が送信を止めて `Breakpoints` のウィンドウが開く。下の`送るボディ`が、いま止まっている中身。")
            ),
            LessonStep(
                String(localized: "ウィンドウ下段の Request 欄で `Body` タブを開く。送ろうとしている JSON がそのまま編集できる。")
            ),
            LessonStep(
                String(localized: "`\"\(LabMarkers.planKey)\"` の行を探し、`\(LabMarkers.planBefore)` をこの値に実際に書き換える。`\(LabMarkers.planUserKey)` の行はそのままでよい。"),
                value: CopyableValue(
                    label: String(localized: "\(LabMarkers.planKey) の新しい値"),
                    value: LabMarkers.planAfter
                )
            ),
            LessonStep(String(localized: "`Execute` を押して送信を再開する。")),
        ],
        material: Material(
            title: String(localized: "送るボディ"),
            kind: .json,
            purpose: String(localized: "アプリがこの JSON を POST します。Proxyman で止めたときに、この中身が出ていることを確かめてください。書き換えの途中で JSON を壊してしまったら、これを貼り直せば元に戻せます。"),
            content: """
                {
                  "\(LabMarkers.planUserKey)": \(LabMarkers.planUserID),
                  "\(LabMarkers.planKey)": "\(LabMarkers.planBefore)"
                }
                """
        ),
        probe: Probe(
            endpoint: .echoBody,
            body: .json("""
                {"\(LabMarkers.planUserKey)": \(LabMarkers.planUserID), "\(LabMarkers.planKey)": "\(LabMarkers.planBefore)"}
                """),
            timeout: 300
        ),
        verify: Verifiers.breakpointBody
    )

    // MARK: 05

    private static let breakpointResponse = Lesson(
        id: .breakpointResponse,
        number: 5,
        title: String(localized: "エラーレスポンスを書き換えて返す"),
        feature: "Breakpoint (Response)",
        goal: String(localized: "サーバが返却したレスポンスを、アプリに返却する前にステータスコードを書き換えます。サーバが 500 を返しても 200 に書き換えて返すことができるので、実装を進めることができます。同じ方法で、正常なレスポンスをエラーに変更することもできます。"),
        steps: [
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Breakpoint` → `Rules…` を開く。")),
            LessonStep(String(localized: "⌘N を押して新しいルールを追加する。")),
            LessonStep(
                String(localized: "Matching Rule の欄に、この値を入れる。"),
                value: CopyableValue(
                    label: "Matching Rule",
                    value: url(.status(LabMarkers.brokenStatus))
                )
            ),
            LessonStep(String(localized: "`Breakpoint` で `Response` にチェックを入れる。`Request` のチェックは外しておく。")),
            LessonStep(String(localized: "`Done` を押す。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押すと、レスポンスが返る直前で止まる。")),
            LessonStep(
                String(localized: "Breakpoints ウィンドウ下段の Response 欄で Other タブを開く。Status Code の欄をクリックし、\(LabMarkers.brokenStatus) から \(LabMarkers.repairedStatus) に変更する。")
            ),
            LessonStep(String(localized: "`Execute` を押す。")),
        ],
        material: nil,
        probe: Probe(endpoint: .status(LabMarkers.brokenStatus), timeout: 300),
        verify: Verifiers.breakpointResponse
    )

    // MARK: 06

    private static let mapRemote = Lesson(
        id: .mapRemote,
        number: 6,
        title: String(localized: "API の向き先を切り替える"),
        feature: "Map Remote",
        goal: String(localized: "特定のサーバ宛のリクエストを、別のサーバへ転送することができます。本番ビルドのままステージングに送信できるので、アプリの修正を行わなくても送信先を切り替えることができます。"),
        steps: [
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Map Remote…` を開く。")),
            LessonStep(String(localized: "⌘N を押して新しいルールを追加する。")),
            LessonStep(String(localized: "この画面は `URL` を 1 本入れる形ではなく、`Protocol` / `Host` / `Port` / `Path` / `Query` の欄に分かれている。`Port` は空でよい。")),
            LessonStep(
                String(localized: "Map From と Map To の Protocol の欄に、この値を入れる。"),
                value: CopyableValue(label: String(localized: "Protocol（両方）"), value: "https")
            ),
            LessonStep(
                String(localized: "Map From と Map To の Host の欄に、この値を入れる。"),
                value: CopyableValue(label: String(localized: "Host（両方）"), value: host.domain)
            ),
            LessonStep(
                String(localized: "Map From と Map To の Path の欄に、この値を入れる。"),
                value: CopyableValue(label: String(localized: "Path（両方）"), value: "/get")
            ),
            LessonStep(
                String(localized: "Map From の Query の欄に、この値を入れる。"),
                value: CopyableValue(
                    label: String(localized: "Map From の Query"),
                    value: LabMarkers.environmentQuery(LabMarkers.productionEnvironment)
                )
            ),
            LessonStep(
                String(localized: "Map To の Query の欄に、この値を入れる。ここだけが Map From と違う。"),
                value: CopyableValue(
                    label: String(localized: "Map To の Query"),
                    value: LabMarkers.environmentQuery(LabMarkers.stagingEnvironment)
                )
            ),
            LessonStep(String(localized: "`Done` を押す。")),
            LessonStep(String(localized: "一覧で `Enable Rule` と `Enable Map Remote Tool` が ON になっていることを確認する。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押す。")),
        ],
        material: nil,
        probe: Probe(endpoint: .echoWithEnvironment(LabMarkers.productionEnvironment)),
        verify: Verifiers.mapRemote
    )

    // MARK: 07

    private static let scripting = Lesson(
        id: .scripting,
        number: 7,
        title: String(localized: "レスポンスを JavaScript で加工する"),
        feature: "Scripting",
        goal: String(localized: "条件に合ったレスポンスを受信するたびに JavaScript を走らせ、中身を書き換えることができます。手では書けない量のデータや境界値を、毎回自動で差し込むことができます。"),
        steps: [
            LessonStep(
                String(localized: "\(menuBar)で Scripting → Script List… を開く。Scripting は Tools の中ではなく、独立したメニュー。")
            ),
            LessonStep(String(localized: "`New Rule` を押す。「+」ではなく `New Rule` というボタン。")),
            LessonStep(
                String(localized: "Matching URLs の種類を Wildcard にし、その欄にこの値を入れる。"),
                value: CopyableValue(
                    label: String(localized: "Matching URLs（Wildcard）:"),
                    value: matchingURL(.echoForLesson("script"))
                )
            ),
            LessonStep(String(localized: "`Script Editor` に下の`貼り付けるスクリプト`を貼り付ける。1 秒後に自動保存される。")),
            LessonStep(String(localized: "`Run Script on Response` を ON にする。このレッスンでは `Request` 側は不要。")),
            LessonStep(String(localized: "`Enable Scripting Tool` と、そのルールの `Enable Rule` が ON になっていることを確認する。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押す。")),
        ],
        material: Material(
            title: String(localized: "貼り付けるスクリプト"),
            kind: .javaScript,
            purpose: String(localized: "Script Editor に貼り付ける。レスポンスに \(LabMarkers.injectedArrayKey) という配列を生やし、手で書けない量のデータをコードで作る。"),
            content: """
                function onResponse(context, url, request, response) {
                  response.body.\(LabMarkers.injectedArrayKey) = Array.from(
                    { length: 20 },
                    (_, index) => ({
                      id: \(LabMarkers.injectedPostID) - index,
                      title: "generated " + index
                    })
                  );
                  return response;
                }
                """
        ),
        probe: Probe(endpoint: .echoForLesson("script")),
        verify: Verifiers.scripting
    )

    // MARK: 08

    private static let blockList = Lesson(
        id: .blockList,
        number: 8,
        title: String(localized: "特定の API をブロックする"),
        feature: "Block List",
        goal: String(localized: "特定のリクエストだけをブロックすることができます。実際の障害は全部のAPIが止まるのではなく一部だけ止まることが多いので、そのときの画面を確認することができます。"),
        steps: [
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Block List…` を開く。")),
            LessonStep(String(localized: "⌘N を押して新しいルールを追加する。")),
            LessonStep(
                String(localized: "Matching Rule の欄に、この値を入れる。他のレッスンとパスが違うので、有効のままでも邪魔にならない。"),
                value: CopyableValue(label: "Matching Rule", value: url(.time))
            ),
            LessonStep(String(localized: "Action で `Block` を選ぶ。`Hide, but not Block` は一覧から隠すだけで、通信は遮断されない。")),
            LessonStep(String(localized: "`Done` を押す。")),
            LessonStep(String(localized: "一覧で `Enable Rule` が ON になっていることを確認する。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押す。")),
        ],
        material: nil,
        probe: Probe(endpoint: .time, timeout: 15),
        verify: Verifiers.blockList
    )

    // MARK: 09

    private static let networkCondition = Lesson(
        id: .networkCondition,
        number: 9,
        title: String(localized: "低速回線を再現する"),
        feature: "Network Conditions",
        goal: String(localized: "特定のリクエストだけを 3G 相当まで遅くすることができます。ローディング表示やタイムアウト処理が実際に動くかを、電波の悪い場所へ行かずに確認することができます。"),
        steps: [
            LessonStep(String(localized: "下の`baseline を計測`を押す。絞る前の所要時間を測っておく。")),
            LessonStep(String(localized: "\(menuBar)で `Tools` → `Network Conditions…` を開く。")),
            LessonStep(String(localized: "`New…` を押して新しいルールを作る。")),
            LessonStep(
                String(localized: "Matching Rule の種類を Wildcard にし、URL の欄にこの値を入れる。"),
                value: CopyableValue(
                    label: String(localized: "URL（Wildcard）"),
                    value: matchingURL(.largePayload)
                )
            ),
            LessonStep(String(localized: "`Profile` で `3G` を選ぶ。数値の `Delay` は入れない。")),
            LessonStep(String(localized: "`Done` を押す。")),
            LessonStep(String(localized: "`Enable Network Conditions` を ON にし、そのルールの `Enable Rule` も ON にする。")),
            LessonStep(String(localized: "アプリに戻って`リクエストを送る`を押す。")),
            LessonStep(String(localized: "終わったら `Enable Network Conditions` を OFF に戻す。他のレッスンが遅くなる。")),
        ],
        material: nil,
        probe: Probe(endpoint: .largePayload, timeout: 60),
        verify: Verifiers.networkCondition
    )
}
