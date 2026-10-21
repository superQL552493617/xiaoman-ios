import SwiftUI

// MARK: - 打卡格子里的「圆点」：底色 + 打卡后的彩色填充 + 边框 + 图标 + 涟漪（和网页版一致）

struct ProtoDot: View {
    let card: Card
    var on: Bool
    var shape: String
    var line: String
    var size: CGFloat = PT.dotSize
    /// 每次打卡加 1，用来触发动画
    var pulse: Int = 0

    @Environment(\.colorScheme) private var scheme
    @State private var fill: CGFloat = 0
    @State private var fillOpacity: Double = 1
    @State private var ripples: [RippleItem] = []

    struct RippleItem: Identifiable { let id = UUID(); var scale: CGFloat; var opacity: Double; var go = false; let to: CGFloat; let ms: Double; let delay: Double }

    private var dark: Bool { scheme == .dark }
    private var cs: CardShape { CardShape(id: shape) }

    var body: some View {
        let ringW: CGFloat = line == "dot" ? (on ? 2.7 : 2.3) : (on ? 1.6 : 1.3)
        ZStack {
            // 底色
            cs.fill(line == "none" && !on ? PT.tile : PT.dotOff)
            // 打卡后的填充
            cs.fill(card.ic == "img" ? Color.clear : PT.fillOn(card.hex, dark: dark))
                .scaleEffect(fill)
                .opacity(fillOpacity)
            // 照片图标铺满
            if card.ic == "img", let ui = ImageData.image(card.icImg) {
                Image(uiImage: ui).resizable().scaledToFill().frame(width: size, height: size).clipShape(cs)
            }
            // 边框
            // 边框整条画在图标里面（不超出图标边界）；虚线、点线用半透明，和底色融在一起
            if line != "none" {
                cs.stroke(on ? PT.ringOn(card.hex, dark: dark) : PT.ringOff, style: strokeStyle(ringW))
                    .opacity(line == "dash" || line == "dot" ? 0.5 : 1)
                    .padding(ringW / 2 + (line == "dot" ? 0.4 : 0))
            }
            // 图标
            if card.ic != "img" { glyph.modifier(ShapeIconFit(shape: shape)) }
            // 涟漪
            ForEach(ripples) { r in
                cs.stroke(PT.vivid(card.hex), lineWidth: 1.6)
                    .scaleEffect(r.go ? r.to : 1)
                    .opacity(r.go ? 0 : r.opacity)
                    .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: r.ms).delay(r.delay), value: r.go)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .onAppear { fill = on ? 1 : 0 }
        .onChange(of: on) { _, v in v ? animateIn() : animateOut() }
    }

    @ViewBuilder private var glyph: some View {
        let cic = size * 0.58
        if card.ic == "text" {
            Text(card.text.isEmpty ? String(card.name.prefix(1)) : card.text)
                .font(PT.cardFont(card.font ?? "round", size: size * 0.33, weight: .bold))
                .foregroundStyle(on ? (dark ? card.colors.fg : PT.ink) : PT.body)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: cic, height: cic)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pulse) { v, s in v.scaleEffect(s) } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.22, duration: 0.2)
                        CubicKeyframe(1.0, duration: 0.24)
                    }
                }
        } else {
            Image(IconCatalog.assetName(card.icon)).resizable().scaledToFit()
                .frame(width: cic, height: cic)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: pulse) { v, s in v.scaleEffect(s) } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.22, duration: 0.2)
                        CubicKeyframe(1.0, duration: 0.24)
                    }
                }
        }
    }

    private func strokeStyle(_ w: CGFloat) -> StrokeStyle {
        // 网页版的虚线、点线按路径总长 100 计算
        let per = .pi * size * 0.97 / 100
        switch line {
        case "dash": return StrokeStyle(lineWidth: w, dash: [2.3 * per, 1.7 * per])
        case "dot": return StrokeStyle(lineWidth: w, lineCap: .round, dash: [0.001, 1.55 * per])
        default: return StrokeStyle(lineWidth: w)
        }
    }

    /// 所有形状都一样：颜色从中心往外长出来，稍微冲过一点再回到原大小
    private func animateIn() {
        fill = 0; fillOpacity = 1
        withAnimation(.timingCurve(0.3, 0.8, 0.4, 1, duration: 0.29)) { fill = 1.08 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.29) {
            withAnimation(.easeOut(duration: 0.15)) { fill = 1 }
        }
        // 涟漪：扩散范围是原来的 1/4，四层更密（和网页版一致）
        ripples = [RippleItem(scale: 1, opacity: 0.8, to: 1.07, ms: 0.42, delay: 0),
                   RippleItem(scale: 1, opacity: 0.65, to: 1.12, ms: 0.48, delay: 0.07),
                   RippleItem(scale: 1, opacity: 0.5, to: 1.18, ms: 0.54, delay: 0.14),
                   RippleItem(scale: 1, opacity: 0.35, to: 1.24, ms: 0.6, delay: 0.21)]
        DispatchQueue.main.async { for i in ripples.indices { ripples[i].go = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { ripples = [] }
    }

    /// 取消打卡：颜色往中心缩回去并变淡（和网页版一样 0.3 秒）
    private func animateOut() {
        fill = 1; fillOpacity = 1
        withAnimation(.easeIn(duration: 0.3)) { fill = 0; fillOpacity = 0.4 }
    }
}

/// 不同形状里，图标的位置和大小微调（和网页版一样）
struct ShapeIconFit: ViewModifier {
    let shape: String
    func body(content: Content) -> some View {
        switch shape {
        case "onigiri": content.scaleEffect(0.86).offset(y: PT.dotSize * 0.58 * 0.07)
        case "heart": content.scaleEffect(0.84).offset(y: -PT.dotSize * 0.58 * 0.03)
        case "flower", "scallop": content.scaleEffect(0.92)
        default: content
        }
    }
}

/// 整个打卡格子：圆点 + 名字 + 状态
struct ProtoCell: View {
    let card: Card
    let rec: Rec?
    var layout: String
    var shape: String
    var line: String
    var pulse: Int
    var width: CGFloat
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { scheme == .dark }
    private var shadowTint: Color { dark ? .black : Color(red: 30/255, green: 30/255, blue: 40/255) }

    var body: some View {
        let on = rec?.checked == true
        VStack(spacing: 0) {
            ProtoDot(card: card, on: on, shape: shape, line: line, pulse: pulse)
                .compositingGroup()
                // 深色模式打卡后：边缘一圈淡淡的同色荧光，像亮的卡片放在暗处
                .shadow(color: dark && on ? PT.vivid(card.hex).opacity(0.42) : shadowTint.opacity(dark ? 0.55 : 0.16),
                        radius: dark && on ? 8 : 5, y: dark && on ? 0 : 4)
                .shadow(color: dark && on ? PT.vivid(card.hex).opacity(0.18) : shadowTint.opacity(dark ? 0.35 : 0.08),
                        radius: dark && on ? 2 : 1, y: dark && on ? 0 : 1)
                .animation(.easeOut(duration: 0.35), value: on)
            Text(card.name)
                .font(PT.cardFont(card.font, size: PT.nameSize(layout)))
                .foregroundStyle(PT.ink)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.top, PT.nameGap(layout))
            Text(sub(on) ?? " ")
                .font(.system(size: 9.5))
                .foregroundStyle(PT.sub)
                .padding(.top, 1)
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name)，\(on ? "已完成" : "未完成")")
        .accessibilityAddTraits(.isButton)
    }

    private func sub(_ on: Bool) -> String? {
        if on {
            if card.isNote { return rec?.hasNote == true ? "已记录" : "待写" }
            return rec?.hasNote == true ? "已写日志" : "已完成"
        }
        return card.isNote ? "记录" : nil
    }
}
