import SwiftUI
import UIKit

enum CoverCategory: String, CaseIterable, Identifiable {
    case landscapes, travel, city, cooking, study, plants, sports, summer, autumn, winter, animals, patterns, plain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: "Study & Work"
        default: rawValue.capitalized
        }
    }
}

/// A notebook cover: an illustration from the asset catalog, a plain cloth colour, or your own photo.
struct Cover: Identifiable, Hashable {
    enum Art: Hashable {
        case image(String)
        case plain(UInt32)
        case photo
    }

    let id: String
    let category: CoverCategory
    let art: Art

    static let photo = Cover(id: "photo", category: .plain, art: .photo)

    static let plainColors: [(String, UInt32)] = [
        ("claret", 0x9B2C3A), ("navy", 0x223F6B), ("bottle", 0x2E6150), ("mustard", 0xD9A520), ("slate", 0x4A5160),
        ("rose", 0xE8B4BC), ("sand", 0xD9C3A0), ("sage", 0x9CB59A), ("ink", 0x26262B), ("rust", 0xC2643F),
        ("teal", 0x1F6B75), ("olive", 0x6F7442), ("lilac", 0xB4A6D6), ("sky", 0x9BC3E0), ("coral", 0xEE8A78),
        ("cream", 0xEFE6D2),
    ]

    static let plain: [Cover] = plainColors.map { Cover(id: "plain-\($0.0)", category: .plain, art: .plain($0.1)) }

    static let all: [Cover] = illustrated + plain

    private static let index: [String: Cover] = Dictionary(uniqueKeysWithValues: (all + [photo]).map { ($0.id, $0) })

    static func find(_ id: String?) -> Cover {
        guard let id else { return named("night-peaks") }
        return index[id] ?? named("night-peaks")
    }

    static func named(_ id: String) -> Cover {
        index[id] ?? illustrated.first ?? plain[0]
    }

    static func covers(in category: CoverCategory) -> [Cover] {
        all.filter { $0.category == category }
    }

    static var randomIllustrated: Cover { illustrated.randomElement() ?? plain[0] }
}

// MARK: - Art

struct CoverArt: View {
    var cover: Cover
    var photo: Data?

    var body: some View {
        switch cover.art {
        case .image(let name):
            Image(name).resizable().scaledToFill()
        case .plain(let hex):
            PlainCloth(color: Color(hex: hex))
        case .photo:
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(hex: 0xA8A196), Color(hex: 0x6F685E)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// Bookcloth: a fine weave with a debossed frame.
struct PlainCloth: View {
    var color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                color
                Canvas { ctx, size in
                    for y in stride(from: 0.0, to: size.height, by: 2.5) {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: .color(.black.opacity(0.06)))
                    }
                    for x in stride(from: 0.0, to: size.width, by: 2.5) {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 0.6, height: size.height)), with: .color(.white.opacity(0.06)))
                    }
                }
                LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: w * 0.02)
                    .strokeBorder(.black.opacity(0.14), lineWidth: max(0.8, w * 0.008))
                    .padding(.vertical, w * 0.1)
                    .padding(.leading, w * 0.16)
                    .padding(.trailing, w * 0.1)
            }
        }
    }
}

// MARK: - Notebook cover with spine, page edges and shadow

struct NotebookCover: View {
    var cover: Cover
    var photo: Data? = nil
    var title: String? = nil
    var showLabel: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let shape = UnevenRoundedRectangle(topLeadingRadius: w * 0.025, bottomLeadingRadius: w * 0.025,
                                               bottomTrailingRadius: w * 0.07, topTrailingRadius: w * 0.07,
                                               style: .continuous)
            ZStack {
                // Pages peeking out
                shape.fill(Color(hex: 0xFBF8F2))
                    .overlay(shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                    .offset(x: w * 0.025, y: w * 0.012)
                    .padding(.vertical, w * 0.02)

                CoverArt(cover: cover, photo: photo)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(shape)
                    .overlay {
                        HStack(spacing: 0) {
                            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .white.opacity(0.18), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: w * 0.11)
                            Spacer()
                        }
                        .clipShape(shape)
                    }
                    .overlay {
                        LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.06)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(shape)
                    }
                    .overlay(shape.strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
                    .overlay(alignment: .center) {
                        if showLabel, let title {
                            Text(title)
                                .font(.system(size: max(10, w * 0.085), weight: .semibold, design: .serif))
                                .foregroundStyle(Color(hex: 0x2A2622))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, w * 0.06)
                                .padding(.vertical, w * 0.035)
                                .frame(maxWidth: w * 0.7)
                                .background(Color(hex: 0xFBF8F2), in: RoundedRectangle(cornerRadius: w * 0.02))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                .offset(x: w * 0.04)
                        }
                    }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.10), radius: w * 0.02, x: 0, y: w * 0.01)
            .shadow(color: .black.opacity(0.14), radius: w * 0.07, x: w * 0.02, y: w * 0.06)
        }
        .aspectRatio(0.72, contentMode: .fit)
    }
}

/// A notebook seen side-on, for the archive shelf.
struct NotebookSpine: View {
    var cover: Cover
    var photo: Data?
    var title: String
    var height: CGFloat = 150

    var body: some View {
        let width = height * 0.24
        ZStack {
            CoverArt(cover: cover, photo: photo)
                .frame(width: height * 0.72, height: height)
                .frame(width: width, height: height)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.25), .white.opacity(0.15), .clear, .black.opacity(0.25)],
                           startPoint: .leading, endPoint: .trailing)
            VStack {
                Rectangle().fill(Color(hex: 0xE9D9A6)).frame(height: 2).padding(.top, 8)
                Rectangle().fill(Color(hex: 0xE9D9A6)).frame(height: 1)
                Spacer()
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: 0x2A2622))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: 0xFBF8F2), in: RoundedRectangle(cornerRadius: 2))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: width, height: height * 0.8)
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1, bottomTrailingRadius: 1, topTrailingRadius: 3))
        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
    }
}
