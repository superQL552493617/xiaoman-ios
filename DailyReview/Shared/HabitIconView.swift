import SwiftUI
import UIKit

enum ImageData {
    /// data URL 或纯 base64 → UIImage
    static func image(_ s: String?) -> UIImage? {
        guard var s, !s.isEmpty else { return nil }
        if let r = s.range(of: "base64,") { s = String(s[r.upperBound...]) }
        guard let d = Data(base64Encoded: s, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: d)
    }

    /// UIImage → 压缩后的 base64（JPEG）
    static func base64(_ img: UIImage, maxSide: CGFloat = 320, quality: CGFloat = 0.8) -> String? {
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let r = UIGraphicsImageRenderer(size: size)
        let out = r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: quality)?.base64EncodedString()
    }
}

/// 卡片中间的图标 / 文字 / 照片
struct HabitGlyph: View {
    let card: Card
    var size: CGFloat
    var textColor: Color = Theme.ink

    var body: some View {
        switch card.ic {
        case "text":
            Text(card.text.isEmpty ? String(card.name.prefix(1)) : card.text)
                .font(.system(size: size * (card.text.count > 1 ? 0.36 : 0.46), weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        case "img":
            if let ui = ImageData.image(card.icImg) {
                Image(uiImage: ui).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Image(IconCatalog.assetName(card.icon)).resizable().scaledToFit().frame(width: size * 0.56, height: size * 0.56)
            }
        default:
            Image(IconCatalog.assetName(card.icon)).resizable().scaledToFit().frame(width: size * 0.56, height: size * 0.56)
        }
    }
}

/// 打卡圆圈：完成时用卡片颜色填满，未完成时是浅色底 + 灰色虚线圈
struct HabitCircle: View {
    let card: Card
    var checked: Bool
    var size: CGFloat = 58
    var square = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let col = card.colors
        let shape = square ? AnyShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)) : AnyShape(Circle())
        ZStack {
            if checked {
                shape.fill(LinearGradient(colors: [col.tint(0.18), col.b], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.stroke(Color.black.opacity(scheme == .dark ? 0.0 : 0.55), lineWidth: 1.4)
            } else {
                shape.fill(scheme == .dark ? Color(hex: "#262624") : Color(hex: "#F7F6F3"))
                shape.stroke(style: StrokeStyle(lineWidth: 1.3, dash: [2.5, 2.5])).foregroundStyle(Color.gray.opacity(0.45))
            }
            HabitGlyph(card: card, size: size, textColor: checked ? col.fg : (scheme == .dark ? .white.opacity(0.85) : Theme.ink))
                .opacity(checked || card.ic == "img" ? 1 : 0.9)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}
