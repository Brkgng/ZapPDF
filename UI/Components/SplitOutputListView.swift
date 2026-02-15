//
//  SplitOutputListView.swift
//  ZapPDF
//
//  Reusable list component for split output preview rows.
//

import SwiftUI

/// Displays a compact list of split output files with optional details.
struct SplitOutputListView: View {

    struct Item: Equatable, Sendable {
        let name: String
        let detail: String?

        init(name: String, detail: String? = nil) {
            self.name = name
            self.detail = detail
        }
    }

    let items: [Item]
    var maxVisibleItems: Int = 5
    var emptyMessage: String = L10n.SplitOptions.noOutput
    var showsTotalCount: Bool = false

    var body: some View {
        if items.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.prefix(maxVisibleItems).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(item.name)
                            .font(.caption.monospaced())

                        Spacer()

                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if items.count > maxVisibleItems {
                    Text(L10n.Dashboard.moreFiles(items.count - maxVisibleItems))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            if showsTotalCount {
                Text(L10n.SplitOptions.totalFiles(items.count))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SplitOutputListView(
            items: [
                .init(name: "source_p1-3.pdf", detail: "Pages 1-3"),
                .init(name: "source_p4-6.pdf", detail: "Pages 4-6"),
                .init(name: "source_p7-9.pdf", detail: "Pages 7-9"),
                .init(name: "source_p10.pdf", detail: "Page 10"),
            ],
            showsTotalCount: true
        )

        SplitOutputListView(items: [])
    }
    .padding()
}
