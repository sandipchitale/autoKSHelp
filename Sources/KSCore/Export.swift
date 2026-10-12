import Foundation

/// One line of an exported listing.
public enum ExportEntry: Equatable {
    case header(String)
    case divider(String)
    case row(title: String, keys: [String], hint: String?)
    /// The Option alternate of the row just above it.
    case alt(title: String, keys: [String])
}

/// The popup's current state, captured for export.
public struct ExportSnapshot {
    public var appName: String
    public var entries: [ExportEntry]
    public var filter: String
    public var alternates: Bool
    public var others: Bool
    public var dark: Bool
    public var date: Date
    /// PNG of the app's icon, shown next to the title.
    public var iconPNG: Data?

    public init(appName: String, entries: [ExportEntry], filter: String, alternates: Bool,
                others: Bool, dark: Bool, date: Date = Date(), iconPNG: Data? = nil) {
        self.appName = appName; self.entries = entries; self.filter = filter
        self.alternates = alternates; self.others = others; self.dark = dark; self.date = date
        self.iconPNG = iconPNG
    }

    /// Label shown (in the accent color, like the alternate rows) when the export includes alternates.
    public var alternatesLabel: String? { alternates ? "Alternates (⌥)" : nil }

    /// "Other commands · filter “x”" — the rest of what the exported view is showing.
    public var otherState: String {
        var parts: [String] = []
        if others { parts.append("Other commands") }
        if !filter.isEmpty { parts.append("filter “\(filter)”") }
        return parts.joined(separator: " · ")
    }

    /// Everything above as plain text.
    public var stateSummary: String {
        [alternatesLabel ?? "", otherState].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public var rowCount: Int { entries.filter { if case .row = $0 { return true } else { return false } }.count }
    public var altCount: Int { entries.filter { if case .alt = $0 { return true } else { return false } }.count }
}

public enum ExportLayout {
    /// Flows entries newspaper-style into columns of `rowsPerColumn` lines, grouped into pages of `columns`.
    /// A column that starts mid-group repeats the group header with "(cont.)"; headers are never left
    /// orphaned at the bottom of a column.
    public static func paginate(_ entries: [ExportEntry], columns: Int, rowsPerColumn: Int) -> [[[ExportEntry]]] {
        let rows = max(4, rowsPerColumn)
        var cols: [[ExportEntry]] = [[]]
        var lastHeader = ""
        for (idx, e) in entries.enumerated() {
            if case .header(let t) = e { lastHeader = t }
            var isLabel = false, isAlt = false
            switch e {
            case .header, .divider: isLabel = true
            case .alt: isAlt = true
            case .row: break
            }
            // A row and its alternate stay together; labels need room for at least two lines after them.
            var need = 1
            if isLabel { need = 3 } else if case .row = e, idx + 1 < entries.count, case .alt = entries[idx + 1] { need = 2 }
            let count = cols[cols.count - 1].count
            if !isAlt && (count >= rows || count + need > rows) && count > 0 {
                cols.append([])
            }
            if cols[cols.count - 1].isEmpty, case .row = e, !lastHeader.isEmpty {
                cols[cols.count - 1].append(.header(lastHeader + " (cont.)"))
            }
            cols[cols.count - 1].append(e)
        }
        var pages: [[[ExportEntry]]] = []
        var i = 0
        while i < cols.count {
            pages.append(Array(cols[i..<min(i + columns, cols.count)]))
            i += columns
        }
        return pages.isEmpty ? [[]] : pages
    }
}

public enum ExportHTML {
    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A self-contained, landscape-printable page that mirrors the popup (4 columns, keycaps).
    public static func render(_ s: ExportSnapshot) -> String {
        let bg = s.dark ? "#202020" : "#ffffff", fg = s.dark ? "#f2f2f2" : "#1d1d1f"
        let dim = s.dark ? "#9a9a9e" : "#6e6e73", cap = s.dark ? "#3a3a3c" : "#ececee"
        let rule = s.dark ? "#3a3a3c" : "#d8d8dc", accent = "#d9622b"
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var body = ""
        for e in s.entries {
            switch e {
            case .header(let t): body += "<h2>\(esc(t))</h2>\n"
            case .divider(let t): body += "<h2 class=\"divider\">\(esc(t))</h2>\n"
            case .row(let title, let keys, let hint):
                let right = keys.isEmpty
                    ? (hint.map { "<span class=\"hint\">\(esc($0))</span>" } ?? "")
                    : "<span class=\"keys\">" + keys.map { "<kbd>\(esc($0))</kbd>" }.joined() + "</span>"
                body += "<div class=\"row\"><span class=\"t\">\(esc(title))</span>\(right)</div>\n"
            case .alt(let title, let keys):
                let right = "<span class=\"keys\">" + keys.map { $0 == "⌥" ? "<kbd class=\"opt\">⌥</kbd>" : "<kbd>\(esc($0))</kbd>" }.joined() + "</span>"
                body += "<div class=\"row alt\"><span class=\"t\">↳ \(esc(title))</span>\(right)</div>\n"
            }
        }
        if s.entries.isEmpty { body = "<p class=\"hint\">Nothing to show.</p>" }
        let metaState = [s.alternatesLabel.map { "<span class=\"altlbl\">\(esc($0))</span>" }, s.otherState.isEmpty ? nil : esc(s.otherState)]
            .compactMap { $0 }.joined(separator: " · ")
        let logo = s.iconPNG.map { "<img class=\"logo\" alt=\"\" src=\"data:image/png;base64,\($0.base64EncodedString())\">" } ?? ""
        return """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <title>\(esc(s.appName)) — keyboard shortcuts</title>
        <style>
        @page { size: landscape; margin: 12mm; }
        * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        body { margin: 0; padding: 24px 28px; background: \(bg); color: \(fg);
               font: 12px/1.35 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
        header { display: flex; justify-content: space-between; align-items: baseline;
                 border-bottom: 1px solid \(rule); padding-bottom: 8px; margin-bottom: 10px; }
        header h1 { font-size: 18px; margin: 0; display: flex; align-items: center; gap: 10px; }
        .logo { width: 28px; height: 28px; }
        header .meta { color: \(dim); font-size: 11px; text-align: right; }
        .cols { column-count: 4; column-gap: 28px; column-rule: 1px solid \(rule); }
        h2 { font-size: 10px; letter-spacing: .06em; text-transform: uppercase; color: \(dim);
             margin: 12px 0 3px; break-after: avoid; }
        h2.divider { color: \(accent); font-weight: 800; }
        .row { display: flex; justify-content: space-between; gap: 8px; padding: 2px 0; break-inside: avoid; }
        .row.alt kbd.opt { color: \(accent); }
        .altlbl { color: \(accent); }
        .row.alt { color: \(accent); padding-left: 10px; margin-top: -1px; }
        .t { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .keys { white-space: nowrap; }
        kbd { display: inline-block; min-width: 17px; margin-left: 2px; padding: 0 3px; text-align: center;
              font: 600 10.5px/16px ui-rounded, -apple-system, sans-serif; background: \(cap); border-radius: 4px; }
        .hint { color: \(dim); font-size: 10px; white-space: nowrap; }
        </style></head>
        <body>
        <header><h1>\(logo)\(esc(s.appName)) — keyboard shortcuts</h1>
        <div class="meta">\(metaState.isEmpty ? "" : metaState + "<br>")\(s.rowCount) items\(s.altCount > 0 ? " + \(s.altCount) alternates" : "") · \(esc(df.string(from: s.date)))</div></header>
        <div class="cols">
        \(body)</div>
        </body></html>
        """
    }
}
