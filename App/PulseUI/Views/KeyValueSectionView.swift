// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

struct KeyValueSectionView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max

    init(viewModel: KeyValueSectionViewModel) {
        self.viewModel = viewModel
    }

    init(viewModel: KeyValueSectionViewModel, limit: Int) {
        self.viewModel = viewModel
        self.limit = limit
    }

    private var actualTintColor: Color {
        viewModel.items.isEmpty ? .gray : viewModel.color
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(viewModel.title)
                    .font(.headline)
                Spacer()
                #if os(iOS)
                if let action = viewModel.action {
                    Button(action: action.action, label: {
                        Text(action.title)
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.gray)
                            .font(.caption)
                            .padding(.top, 2)
                    })
                    .foregroundColor(.primary)
                    .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .background(Color.secondaryFill)
                    .cornerRadius(12)
                    .frame(height: 20, alignment: .center)
                }
                #endif
            }
            #if os(watchOS)
            KeyValueListView(viewModel: viewModel, limit: limit)
                .padding(.top, 6)
                .border(width: 2, edges: [.top], color: actualTintColor)
                .padding(.top, 2)

            if let action = viewModel.action {
                Spacer().frame(height: 10)
                Button(action: action.action, label: {
                    Text(action.title)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.separator)
                        .font(.caption)
                })

            }

            #else
            KeyValueListView(viewModel: viewModel, limit: limit)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                .border(width: 2, edges: [.leading], color: actualTintColor)
                .padding(EdgeInsets(top: 5, leading: 2, bottom: 5, trailing: 0))
            #endif
        }
    }
}

private struct KeyValueListView: View {
    let viewModel: KeyValueSectionViewModel
    var limit: Int = Int.max

    private var actualTintColor: Color {
        viewModel.items.isEmpty ? .gray : viewModel.color
    }

    var items: [(String, String?)] {
        var items = Array(viewModel.items.prefix(limit))
        if viewModel.items.count > limit {
            items.append(("And \(viewModel.items.count - limit) more", "..."))
        }
        return items
    }

#if os(macOS)
    var body: some View {
        if viewModel.items.isEmpty {
            HStack {
                Text("Empty")
                    .foregroundColor(actualTintColor)
                    .font(.system(size: fontSize, weight: .medium))
            }
        } else {
            Label(text: text)
                .padding(.bottom, 5)
        }
    }

    private var text: NSAttributedString {
        let text = NSMutableAttributedString()
        for (index, row) in items.enumerated() {
            text.append(makeRow(row))
            if index != items.indices.last {
                text.append("\n")
            }
        }
        return text
    }

    private func makeRow(_ row: (String, String?)) -> NSAttributedString {
        let text = NSMutableAttributedString()
        text.append(row.0 + ": ", [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(actualTintColor),
            .paragraphStyle: ps
        ])
        text.append(row.1 ?? "–", [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(Color.primary),
            .paragraphStyle: ps
        ])
        return text
    }
    #else
    var body: some View {
        if viewModel.items.isEmpty {
            HStack {
            Text("Empty")
                .foregroundColor(actualTintColor)
                .font(.system(size: fontSize, weight: .medium))
            }
        } else {
            VStack(spacing: 2) {
                let rows = items.enumerated().map(Row.init)
                ForEach(rows, id: \.index, content: makeRow)
            }
        }
    }

    private func makeRow(_ row: Row) -> some View {
        HStack {
            let title = Text(row.item.0 + ": ")
                .foregroundColor(actualTintColor)
                .font(.system(size: fontSize, weight: .medium))
            let value = Text(row.item.1 ?? "–")
                .foregroundColor(.primary)
                .font(.system(size: fontSize, weight: .regular))
            (title + value)
                .lineLimit(row.item.0 == "URL" ? 8 : 3)
#if os(iOS)
                .contextMenu(ContextMenu(menuItems: {
                    Button(action: {
                        UXPasteboard.general.string = "\(row.item.0): \(row.item.1 ?? "–")"
                        runHapticFeedback()
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    }
                    Button(action: {
                        UXPasteboard.general.string = row.item.1
                        runHapticFeedback()
                    }) {
                        Text("Copy Value")
                        Image(systemName: "doc.on.doc")
                    }
                }))
#endif
            Spacer()
        }
    }
    #endif
}

#if os(macOS)
private struct Label: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField.label()
        label.isSelectable = true
        label.allowsEditingTextAttributes = true
        label.lineBreakMode = .byCharWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.attributedStringValue = text
    }
}

private let ps: NSParagraphStyle = {
    let ps = NSMutableParagraphStyle()
    ps.minimumLineHeight = 20
    ps.maximumLineHeight = 20
    return ps
}()
#endif

private var fontSize: CGFloat {
    #if os(iOS)
    return 15
    #elseif os(watchOS)
    return 14
    #elseif os(tvOS)
    return 28
    #else
    return 12
    #endif
}

struct KeyValueSectionViewModel {
    let title: String
    let color: Color
    var action: ActionViewModel?
    var items: [(String, String?)] = []
}

private struct Row {
    let index: Int
    let item: (String, String?)
}

struct ActionViewModel {
    let action: () -> Void
    let title: String
}
