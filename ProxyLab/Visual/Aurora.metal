//
//  Aurora.metal
//  ProxyLab
//
//  Created by Hideo Endo on 2026/08/08.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// 背景のオーロラ。colorEffect 用の [[stitchable]] 関数で、
// 引数は (座標, 元の色, ビューのサイズ, 経過秒, 明るさ 0...1)。
//
// 色は Proxyman のキーカラーの青。Proxyman.app のアイコン（上 #00B0F0 → 下 #0068E8）と
// 公式サイトのアクセント #4F8CFF から採り、空色を主役に、深い青を差し色として重ねる。

constant float3 kSky   = float3(0.00, 0.69, 0.94);
constant float3 kAzure = float3(0.31, 0.55, 1.00);
constant float3 kDeep  = float3(0.00, 0.41, 0.91);

/// 地の色。白いセルを載せるので、純白ではなく systemGroupedBackground 相当の薄い灰にする。
constant float3 kDay = float3(0.949, 0.949, 0.969);

/// 帯の色をどれだけ白に寄せるか。0 で原色、1 で真っ白。地が白なので淡くしないと文字が沈む。
constant float kPastel = 0.45;

/// どれだけ「いちばん強い帯の色」に寄せるか。
/// 1 で単純な重み平均（＝混ざって濁る）、大きいほど強い帯の色が勝つ。
constant float kDominance = 3.0;

/// 帯を 1 本足す。
///
/// 光を足し算で混ぜると、黄（R+G）と青（B）が重なった画素が白に寄って濁る。
/// そこで「色」と「明るさ」を分けて持つ。色は強い帯ほど重く数え、明るさだけを足し込む。
static void addCurtain(thread float3 &tintSum,
                       thread float &weightSum,
                       thread float &brightness,
                       float3 color,
                       float amount) {
    float dominance = pow(max(amount, 0.0), kDominance);
    tintSum += color * dominance;
    weightSum += dominance;
    brightness += amount;
}

static float auroraHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float auroraNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(auroraHash(i), auroraHash(i + float2(1.0, 0.0)), u.x),
               mix(auroraHash(i + float2(0.0, 1.0)), auroraHash(i + float2(1.0, 1.0)), u.x),
               u.y);
}

/// 揺らぎ。オクターブを重ねて雲のような濃淡を作る。
static float auroraFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * auroraNoise(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return value;
}

/// カーテン 1 本。横に流れながら上下にうねる帯。
/// `center` が帯の基準の高さ、`thickness` が広がり。
static float curtain(float2 uv,
                     float center,
                     float freq,
                     float speed,
                     float thickness,
                     float warp,
                     float time) {
    float wave = 0.085 * sin(uv.x * freq + time * speed)
               + 0.045 * sin(uv.x * freq * 1.9 - time * speed * 0.7)
               + 0.110 * warp;
    float d = uv.y - (center + wave);

    // 端に向かって細くなる。帯が画面を横切って切れているように見せない。
    float taper = thickness * (0.75 + 0.45 * sin(uv.x * 2.1 + time * 0.2));
    return exp(-(d * d) / (taper * taper));
}

[[stitchable]] half4 auroraBackground(float2 position,
                                      half4 color,
                                      float2 size,
                                      float time,
                                      float intensity) {
    float2 uv = position / size;

    // 全体のうねり。カーテンをまとめて押し流す。
    float warp = auroraFbm(uv * float2(1.7, 2.4) + float2(time * 0.055, time * 0.030)) - 0.5;

    float3 tintSum = float3(0.0);
    float weightSum = 0.0;
    float brightness = 0.0;

    // 空色が主役。ただし総量は抑えるので、太くしすぎず本数で見せる。
    addCurtain(tintSum, weightSum, brightness, kSky,
               0.85 * curtain(uv, 0.30, 3.1,  0.34, 0.130, warp,        time));
    addCurtain(tintSum, weightSum, brightness, kSky,
               0.45 * curtain(uv, 0.56, 2.4, -0.27, 0.105, warp * 0.80, time));
    addCurtain(tintSum, weightSum, brightness, kAzure,
               0.32 * curtain(uv, 0.44, 3.7,  0.21, 0.090, warp,        time));

    // 深い青は差し色にとどめる。空色の帯とは高さを離して、重なりを減らす。
    addCurtain(tintSum, weightSum, brightness, kDeep,
               0.28 * curtain(uv, 0.72, 2.9, -0.40, 0.100, warp * 1.20, time));
    addCurtain(tintSum, weightSum, brightness, kAzure,
               0.24 * curtain(uv, 0.87, 3.4,  0.30, 0.120, warp * 0.60, time));
    addCurtain(tintSum, weightSum, brightness, kDeep,
               0.16 * curtain(uv, 0.14, 2.6, -0.19, 0.085, warp,        time));

    // その画素の色。混色ではなく、いちばん強い帯の色に寄る。
    float3 tint = tintSum / max(weightSum, 1e-5);

    // 細かいちらつき。均一な塗りに見せない。
    float shimmer = auroraFbm(uv * float2(6.0, 3.0) + float2(time * 0.18, time * 0.09));
    brightness *= 0.82 + 0.36 * shimmer;

    // 上下は落とす。画面いっぱいに光らせると文字が読みにくい。
    brightness *= smoothstep(0.02, 0.22, uv.y) * smoothstep(1.02, 0.80, uv.y);

    // 指数トーンマップ。明るさだけを潰すので、色は濁らない。
    float lit = 1.0 - exp(-max(brightness, 0.0) * clamp(intensity, 0.0, 1.0));

    // 白地に光を足すと白に飛ぶので、地の色から淡い青へ寄せる形で描く。
    float3 pastel = mix(float3(1.0), tint, 1.0 - kPastel);
    return half4(half3(mix(kDay, pastel, lit)), 1.0h);
}
