// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).
// Licensed under Apache License v2.0 with Runtime Library Exception.

import SwiftUI
import Pulse
import Logging

struct ConsoleMessageView: View {
    let model: ConsoleMessageViewModel

    #if os(iOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.title)
                .font(.caption)
                .foregroundColor(model.style.titleColor)
            Text(model.text)
                .font(.body)
                .foregroundColor(model.style.textColor)
                .lineLimit(4)
        }.padding(.vertical, 4)
    }
    #endif

    #if os(macOS)
    var body: some View {
        VStack(alignment: .leading) {
            Text(model.title)
                .font(.system(size: 10))
                .foregroundColor(model.style.titleColor)
            Text(model.text)
                .font(.system(size: 12))
                .foregroundColor(model.style.textColor)
                .lineLimit(4)
        }.padding(.vertical, 6)
    }
    #endif
}

struct ConsoleMessageStyle {
    let titleColor: Color
    let textColor: Color
    let backgroundColor: Color

    static func make(level: Logger.Level) -> ConsoleMessageStyle {
        switch level {
        case .trace: return .debug
        case .debug: return .debug
        case .info: return .info
        case .notice: return .error
        case .warning: return .error
        case .error: return .fatal
        case .critical: return .fatal
        }
    }

    static let debug = ConsoleMessageStyle(
        titleColor: .secondary,
        textColor: .primary,
        backgroundColor: .clear
    )

    static let info = ConsoleMessageStyle(
        titleColor: .primary,
        textColor: .primary,
        backgroundColor: .blue
    )

    static let error = ConsoleMessageStyle(
        titleColor: .orange,
        textColor: .orange,
        backgroundColor: .orange
    )

    static let fatal = ConsoleMessageStyle(
        titleColor: .red,
        textColor: .red,
        backgroundColor: .red
    )

    static func backgroundColor(for message: MessageEntity, colorScheme: ColorScheme) -> Color {
        let style = ConsoleMessageStyle.make(level: Logger.Level(rawValue: message.level) ?? .debug)
        return style.backgroundColor.opacity(colorScheme == .dark ? 0.1 : 0.05)
    }
}

struct ConsoleMessageView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .debug)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .info)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .error)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .fatal)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .debug)
            ).previewDisplayName("Debug Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .info)
            ).previewDisplayName("Info Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .error)
            ).previewDisplayName("Error Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .fatal)
            ).previewDisplayName("Fatal Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                 ConsoleMessageViewModel(title: "Today 5:00 PM | application:networking", text: "Aenean vel ullamcorper ipsum. Pellentesque viverra fringilla accumsan. Vestibulum blandit accumsan tortor, viverra laoreet augue rutrum et. Praesent quis libero est. Duis imperdiet, eros sit amet commodo tincidunt, risus est interdum mi, sit amet sagittis nunc sapien et orci. Phasellus lectus ante, rutrum vel lorem vitae, interdum elementum erat. ", style: .debug)
             ).previewLayout(.sizeThatFits)
        }
    }
}