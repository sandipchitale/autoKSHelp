import SwiftUI
import AppKit

/// Landscape PDF of an `ExportSnapshot`, paginated, vector text.
@MainActor
public enum PDFExporter {
    /// A4 landscape in metric locales, US Letter landscape otherwise (points).
    public static var pageSize: CGSize {
        Locale.current.measurementSystem == .metric ? CGSize(width: 842, height: 595) : CGSize(width: 792, height: 612)
    }

    static let margin: CGFloat = 28, headerH: CGFloat = 44, rowH: CGFloat = 15.5, gap: CGFloat = 18, columns = 4

    public static func pages(for s: ExportSnapshot, size: CGSize) -> [[[ExportEntry]]] {
        let body = size.height - 2 * margin - headerH
        return ExportLayout.paginate(s.entries, columns: columns, rowsPerColumn: Int(body / rowH))
    }

    public static func write(_ s: ExportSnapshot, to url: URL) throws {
        let size = pageSize
        let pages = Self.pages(for: s, size: size)
        var box = CGRect(origin: .zero, size: size)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for (i, cols) in pages.enumerated() {
            let view = PageView(snapshot: s, columns: cols, page: i + 1, pageCount: pages.count, size: size)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(size)
            renderer.render { _, draw in
                ctx.beginPDFPage(nil)
                draw(ctx)
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()
    }

    struct PageView: View {
        let snapshot: ExportSnapshot
        let columns: [[ExportEntry]]
        let page: Int, pageCount: Int
        let size: CGSize

        var fg: Color { snapshot.dark ? Color(white: 0.95) : Color(white: 0.11) }
        var dim: Color { snapshot.dark ? Color(white: 0.62) : Color(white: 0.43) }
        var cap: Color { snapshot.dark ? Color(white: 0.23) : Color(white: 0.93) }
        var rule: Color { snapshot.dark ? Color(white: 0.23) : Color(white: 0.85) }

        var body: some View {
            let colW = (size.width - 2 * PDFExporter.margin - CGFloat(PDFExporter.columns - 1) * PDFExporter.gap)
                / CGFloat(PDFExporter.columns)
            VStack(alignment: .leading, spacing: 0) {
                header.frame(height: PDFExporter.headerH, alignment: .top)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<PDFExporter.columns, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array((i < columns.count ? columns[i] : []).enumerated()), id: \.offset) { _, e in
                                entry(e, width: colW)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: colW, alignment: .topLeading)
                        if i < PDFExporter.columns - 1 {
                            Rectangle().fill(rule).frame(width: 0.5)
                                .padding(.horizontal, PDFExporter.gap / 2 - 0.25)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(PDFExporter.margin)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(snapshot.dark ? Color(white: 0.125) : Color.white)
            .environment(\.colorScheme, snapshot.dark ? .dark : .light)
        }

        var header: some View {
            let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
            let dimText: (String) -> Text = { Text($0).foregroundColor(dim) }
            var meta = Text("")
            if let alt = snapshot.alternatesLabel { meta = meta + Text(alt).foregroundColor(altColor) + dimText(" · ") }
            if !snapshot.otherState.isEmpty { meta = meta + dimText(snapshot.otherState + " · ") }
            meta = meta + dimText("\(snapshot.rowCount) items"
                                  + (snapshot.altCount > 0 ? " + \(snapshot.altCount) alternates" : "")
                                  + " · \(df.string(from: snapshot.date)) · page \(page)/\(pageCount)")
            return VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .center, spacing: 8) {
                        if let data = snapshot.iconPNG, let img = NSImage(data: data) {
                            Image(nsImage: img).resizable().interpolation(.high).frame(width: 22, height: 22)
                        }
                        Text("\(snapshot.appName) — keyboard shortcuts")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(fg)
                    }
                    Spacer()
                    meta.font(.system(size: 8.5))
                }
                Rectangle().fill(rule).frame(height: 0.5)
            }
        }

        var altColor: Color { Color(red: 0.85, green: 0.38, blue: 0.17) }

        /// `tintOption` draws the ⌥ glyph in the alternate color (used on alternate rows).
        func keycaps(_ keys: [String], tintOption: Bool = false) -> some View {
            HStack(spacing: 1.5) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                    Text(k).font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundColor(tintOption && k == "⌥" ? altColor : fg)
                        .frame(minWidth: 11).padding(.horizontal, 1.5).padding(.vertical, 0.5)
                        .background(cap, in: RoundedRectangle(cornerRadius: 3))
                }
            }
        }

        @ViewBuilder func entry(_ e: ExportEntry, width: CGFloat) -> some View {
            switch e {
            case .header(let t):
                Text(t.uppercased()).font(.system(size: 7.5, weight: .bold)).foregroundColor(dim)
                    .frame(width: width, height: PDFExporter.rowH, alignment: .bottomLeading)
            case .divider(let t):
                Text(t.uppercased()).font(.system(size: 7.5, weight: .heavy)).foregroundColor(Color(red: 0.85, green: 0.38, blue: 0.17))
                    .frame(width: width, height: PDFExporter.rowH, alignment: .bottomLeading)
            case .alt(let title, let keys):
                HStack(spacing: 4) {
                    Text("↳ " + title).font(.system(size: 9)).foregroundColor(altColor).lineLimit(1)
                    Spacer(minLength: 2)
                    keycaps(keys, tintOption: true)
                }
                .padding(.leading, 8)
                .frame(width: width, height: PDFExporter.rowH)
            case .row(let title, let keys, let hint):
                HStack(spacing: 4) {
                    Text(title).font(.system(size: 9)).foregroundColor(fg).lineLimit(1)
                    Spacer(minLength: 2)
                    if keys.isEmpty {
                        if let hint { Text(hint).font(.system(size: 6.5)).foregroundColor(dim).lineLimit(1) }
                    } else {
                        keycaps(keys)
                    }
                }
                .frame(width: width, height: PDFExporter.rowH)
            }
        }
    }
}
