//
//  AuroraBackground.swift
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

import SwiftUI

/// 背景のオーロラ。Metal で毎フレーム描く。
///
/// 明るさは `intensity` で渡す。SwiftUI のアニメーションはシェーダの引数を補間しないので、
/// 変化させたいときは時刻から計算して渡すこと。
struct AuroraBackground: View {

    /// 0 で消灯、1 で最大。文字の下に敷くので既定は控えめにする。
    var intensity: Double = 0.70

    /// 動きの速さ。1.0 が既定で、0.5 なら半分、2.0 なら倍。
    ///
    /// 速さの指定はシェーダ側の 4 箇所（カーテンごとの流れ・全体のうねり・帯の揺れ・ちらつき）に
    /// 散っている。まとめて変えたいだけなら、渡す経過秒をここで伸縮させるほうが早い。
    var speed: Double = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 経過秒は起点からの相対値にする。参照日からの絶対秒は float の精度を超え、
    /// シェーダ内で動きが階段状になる。
    @State private var epoch = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(epoch) * speed
            let time = Float(elapsed)

            Rectangle()
                // colorEffect が全画素を置き換えるので、この色自体は使われない
                .fill(.black)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        // Aurora.metal の [[stitchable]] 関数名
                        ShaderLibrary[dynamicMember: "auroraBackground"](
                            .float2(proxy.size),
                            .float(time),
                            .float(Float(intensity))
                        )
                    )
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    AuroraBackground()
}
