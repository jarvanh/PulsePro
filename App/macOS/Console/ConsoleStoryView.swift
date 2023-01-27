// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine
import WebKit

#warning("use the view from the main framework")

struct ConsoleStoryView: View {
    @StateObject private var viewModel: ConsoleStoryViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    init(viewModel: ConsoleMainViewModel) {
        _viewModel = StateObject(wrappedValue: ConsoleStoryViewModel(main: viewModel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleStoryOptionsView(viewModel: viewModel)
            Divider()
            RichTextViewPro(
                viewModel: viewModel.text,
                content: .story,
                onLinkClicked: viewModel.onLinkClicked,
                rulerWidth: 27
            )
                .id(ObjectIdentifier(viewModel.text)) // TODO: fix this
                .background(colorScheme == .dark ? Color(NSColor(red: 30/255.0, green: 30/255.0, blue: 30/255.0, alpha: 1)) : .clear)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}

private struct ConsoleStoryOptionsView: View {
    @ObservedObject var viewModel: ConsoleStoryViewModel
    
    var body: some View {
        HStack {
            Toggle("Compact Mode", isOn: AppSettings.shared.$isStoryCompactModeEnabled)
            Toggle("Limit to Thousand", isOn: AppSettings.shared.$isStoryReducedCount)
            Toggle("Show Responses", isOn: AppSettings.shared.$isStoryNetworkExpanded)
            Spacer()
        }
        .padding([.leading, .trailing], 6)
        .frame(height: 29, alignment: .center)
    }
}

final class ConsoleStoryViewModel: NSObject, ObservableObject {
    let main: ConsoleMainViewModel
    let text = RichTextViewModelPro(string: .init())
    @Published var isRefreshButtonVisible = false
    
    private var ids: [UUID: NSManagedObjectID] = [:]
    private var cache: [NSManagedObjectID: MessageViewModel] = [:]
    
    private var cancellables: [AnyCancellable] = []
    private let queue = DispatchQueue(label: "com.github.kean.pulse.story")
    private var options: Options
    private var helpers: TextRenderingHelpers
            
    init(main: ConsoleMainViewModel) {
        self.main = main
        self.options = ConsoleStoryViewModel.makeOptions()
        self.helpers = TextRenderingHelpers(options: options)
        
        super.init()
  
        UserDefaults.standard.publisher(for: \.isStoryNetworkExpanded, options: [.new]).sink { [weak self] _ in
            self?.didRefreshOptions()
        }.store(in: &cancellables)
        
        UserDefaults.standard.publisher(for: \.isStoryCompactModeEnabled, options: [.new]).sink { [weak self] _ in
            self?.didRefreshOptions()
        }.store(in: &cancellables)
        
        UserDefaults.standard.publisher(for: \.isStoryReducedCount, options: [.new]).sink { [weak self] _ in
            self?.didRefreshOptions()
        }.store(in: &cancellables)
        
        UserDefaults.standard.publisher(for: \.storyFontSize, options: [.new]).sink { [weak self] _ in
            self?.didRefreshOptions()
        }.store(in: &cancellables)
        
        main.toolbar.$isNowEnabled.dropFirst().sink { [weak text] in
            if $0 {
                text?.scrollToBottom()
            }
        }.store(in: &cancellables)
        
        text.didLiveScroll = { [weak main] in
            main?.toolbar.isNowEnabled = false
        }
        
        main.list.updates.sink { [weak self] in
            self?.process(update: $0)
        }.store(in: &cancellables)
        
        didRefreshMessages()
    }
    
    func onAppear() {
        if main.toolbar.isNowEnabled {
            DispatchQueue.main.async {
                self.text.scrollToBottom()
            }
        }
    }
    
    private func process(update: FetchedObjectsUpdate) {
        switch update {
        case .append(let range):
            let t = makeText(indices: range)
            if t.length > 0 {
                let s = NSMutableAttributedString(string: "\n")
                s.append(t)
                text.append(text: s)
                if main.toolbar.isNowEnabled {
                    text.scrollToBottom()
                }
            }
        case .reload:
            didRefreshMessages()
        }
    }
    
    private func didRefreshOptions() {
        options = ConsoleStoryViewModel.makeOptions()
        helpers = TextRenderingHelpers(options: options)
        cache.values.forEach { $0.isDirty = true }
        didRefreshMessages()
        objectWillChange.send()
    }
    
    private func didRefreshMessages() {
        text.display(text: makeText())
        if main.toolbar.isNowEnabled {
            text.scrollToBottom()
        }
    }
    
    func onLinkClicked(_ url: URL) -> Bool {
        guard url.scheme == "story" else {
            return false
        }
        let string = url.absoluteString
        
        if string.hasPrefix("story://toggle-message-limit") {
            AppSettings.shared.isStoryReducedCount = false
            return true
        }
        if string.hasPrefix("story://toggle-info") {
            let uuidString = url.lastPathComponent
            guard let uuid = UUID(uuidString: uuidString), let objectID = ids[uuid], let model = cache[objectID] else {
                assertionFailure()
                return false
            }
            self.main.selectEntityAt(model.index)
            return true
        }
 
        return true
    }
}

// MARK: - Regular Messages

#warning("TODO: add pins")

// TODO:
// - Cache RenderingCache per Options

extension ConsoleStoryViewModel {
    final class Options {
        let isNetworkExpanded: Bool
        let isCompactMode: Bool
        let isStoryReducedCount: Bool
        let fontSize: CGFloat
        
        init(isNetworkExpanded: Bool, isCompactMode: Bool, isStoryReducedCount: Bool, fontSize: CGFloat) {
            self.isNetworkExpanded = isNetworkExpanded
            self.isCompactMode = isCompactMode
            self.isStoryReducedCount = isStoryReducedCount
            self.fontSize = fontSize
        }
    }
    
    final class TextRenderingHelpers {
        let ps: NSParagraphStyle
        
        // Cache
        let digitalAttributes: [NSAttributedString.Key: Any]
        let titleAttributes: [NSAttributedString.Key: Any]
        private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]
        
        let infoIconAttributes: [NSAttributedString.Key: Any]
        let showAllAttributes: [NSAttributedString.Key: Any]
        
        init(options: Options) {
            let ps = NSParagraphStyle.make(lineHeight: Constants.ResponseViewer.lineHeight(for: Int(options.fontSize)))
            self.ps = ps
            
            self.digitalAttributes = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: options.fontSize, weight: .regular),
                .foregroundColor: UXColor.secondaryLabel,
                .paragraphStyle: ps
            ]
            
            self.titleAttributes = [
                .font: NSFont.systemFont(ofSize: options.fontSize),
                .foregroundColor: UXColor.secondaryLabel,
                .paragraphStyle: ps
            ]
            
            var infoIconAttributes = titleAttributes
            infoIconAttributes[.foregroundColor] = NSColor.controlAccentColor
            self.infoIconAttributes = infoIconAttributes
            
            self.showAllAttributes = [
                .font: NSFont.systemFont(ofSize: options.fontSize),
                .foregroundColor: NSColor.systemBlue,
                .paragraphStyle: ps
            ]
            
            func makeLabelAttributes(level: LoggerStore.Level) -> [NSAttributedString.Key: Any] {
                let textColor = level == .trace ? .secondaryLabel : NSColor.textColor(for: level)
                return [
                    .font: NSFont.systemFont(ofSize: options.fontSize),
                    .foregroundColor: textColor,
                    .paragraphStyle: ps
                ]
            }
             
            for level in LoggerStore.Level.allCases {
                textAttributes[level] = makeLabelAttributes(level: level)
            }
        }
    }
    
    private static func makeOptions() -> Options {
        Options(
            isNetworkExpanded: AppSettings.shared.isStoryNetworkExpanded,
            isCompactMode: AppSettings.shared.isStoryCompactModeEnabled,
            isStoryReducedCount: AppSettings.shared.isStoryReducedCount,
            fontSize: CGFloat(AppSettings.shared.storyFontSize)
        )
    }
    
    private func makeText(indices: Range<Int>? = nil) -> NSAttributedString {
        let date = Date()
        pulseLog("Start rendering text view \(date)")
        defer { pulseLog("Finished rendering \(date), \(stringPrecise(from: Date().timeIntervalSince(date)))") }
        return makeText(indices: indices ?? main.list.indices, options: options, helpers: helpers)
    }
    
    private func makeText(indices: Range<Int>, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let messages = main.list
        let lastIndex = main.list.count - 1
        for index in indices {
            if options.isStoryReducedCount && index > 999 {
                break
            }
            text.append(makeText(for: messages[index], index: index, options: options, helpers: helpers))
            if options.isStoryReducedCount && index == 999 {
                let remaining = messages.count - (index + 1)
                if remaining > 0 {
                    text.append("\n\n\(remaining)+ messages were not displayed. ", helpers.textAttributes[.trace]!)
                    var showAllAttributes = helpers.showAllAttributes
                    showAllAttributes[.link] = URL(string: "story://toggle-message-limit")
                    text.append("Show all.", showAllAttributes)
                }
                break
            }
            if index != lastIndex {
                if options.isCompactMode {
                    text.append("\n", helpers.digitalAttributes)
                } else {
                    text.append("\n\n", helpers.digitalAttributes)
                }
            }
        }
        return text
    }
    
    private func makeToggleInfoURL(for id: UUID) -> URL {
        URL(string: "story://toggle-info/\(id.uuidString)")!
    }
    
    private func getInterval(for message: LoggerMessageEntity) -> TimeInterval {
        guard let first = main.list.first else { return 0 }
        return message.createdAt.timeIntervalSince1970 - first.createdAt.timeIntervalSince1970
    }
    
    private func makeText(for message: LoggerMessageEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        if let task = message.task {
            return makeText(for: message, task: task, index: index, options: options, helpers: helpers)
        }
        
        let model = getMessageModel(for: message, at: index)
        if !model.isDirty {
            return model.text
        }
        model.isDirty = false
        
        let text = NSMutableAttributedString()

        // Title
        let time = ConsoleMessageCellViewModel.timeFormatter.string(from: message.createdAt)
        
        // Title first part (digital)
        var titleFirstPart = "\(time) · "
        if !options.isCompactMode {
            let interval = getInterval(for: message)
            if interval < 3600 * 24 {
                titleFirstPart.append(contentsOf: "\(stringPrecise(from: interval)) · ")
            }
        }
        text.append(titleFirstPart, helpers.digitalAttributes)
        
        // Title second part (regular)
        let level = message.logLevel
        var titleSecondPart = options.isCompactMode ? "" : "\(level.name) · "
        titleSecondPart.append("\(message.label)")
        titleSecondPart.append(options.isCompactMode ? " " : "\n")
        text.append(titleSecondPart, helpers.titleAttributes)
        
        // Text
        let textAttributes = helpers.textAttributes[level]!
        if options.isCompactMode {
            if let newlineIndex = message.text.firstIndex(of: "\n") {
                text.append(message.text[..<newlineIndex] + " ", textAttributes)
                var moreAttr = helpers.showAllAttributes
                moreAttr[.link] = makeToggleInfoURL(for: model.id)
                text.append("Show More", moreAttr)
            } else {
                text.append(message.text, textAttributes)
            }
        } else {
            text.append(message.text, textAttributes)
        }

        model.text = text
        return text
    }
    
    private func makeText(for message: LoggerMessageEntity, task: NetworkTaskEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        let model = getMessageModel(for: message, at: index)
        if !model.isDirty {
            return model.text
        }
        model.isDirty = false
        
        let text = NSMutableAttributedString()

        // Title
        let state = task.state
        let time = ConsoleMessageCellViewModel.timeFormatter.string(from: message.createdAt)
        var prefix: String
        switch state {
        case .pending:
            prefix = "PENDING"
        case .success:
            prefix = StatusCodeFormatter.string(for: Int(task.statusCode))
        case .failure:
            if task.errorCode != 0 {
                prefix = "\(task.errorCode) (\(descriptionForURLErrorCode(Int(task.errorCode))))"
            } else {
                prefix = StatusCodeFormatter.string(for: Int(task.statusCode))
            }
        }

        let tintColor: NSColor = {
            switch state {
            case .pending: return .systemYellow
            case .success: return .systemGreen
            case .failure: return Palette.red
            }
        }()
        
        var title = "\(prefix)"
        if task.duration > 0 {
            title += " · \(DurationFormatter.string(from: task.duration))"
        }
        
        text.append("\(time) · ", helpers.digitalAttributes)
        if !options.isCompactMode  {
            let interval = getInterval(for: message)
            if interval < 3600 * 24 {
                text.append("\(stringPrecise(from: interval)) · ", helpers.digitalAttributes)
            }
        }
        text.append(title + " ", {
            var attributes = helpers.titleAttributes
            attributes[.foregroundColor] = tintColor
            return attributes
        }())
//        text.append(title + " ", helpers.titleAttributes)
        text.append(options.isCompactMode ? " " : "\n", helpers.titleAttributes)

        // Text
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        let textAttributes = helpers.textAttributes[level]!
        let method = task.httpMethod ?? "GET"
        let messageText = method + " " + (task.url ?? "–")

        text.append(messageText + " ", {
            var attributes = textAttributes
            attributes[.link] = makeToggleInfoURL(for: model.id)
            attributes[.underlineColor] = NSColor.systemBlue
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.foregroundColor] = NSColor.systemBlue
            return attributes
        }())

        if options.isNetworkExpanded, let data = task.responseBody?.data {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                #warning("is it ok?")
                text.append("\n")
                let string = JSONViewModel(json: json).format(json: json)
                text.append(string)
            } else if let string = String(data: data, encoding: .utf8) {
                text.append("\n")
                text.append(string, helpers.textAttributes[.debug]!)
            }
        }
        
        model.text = text
        return text
    }
    
    private func getMessageModel(for message: LoggerMessageEntity, at index: Int) -> MessageViewModel {
        if let model = cache[message.objectID] { return model }
        let model = MessageViewModel(index: index)
        cache[message.objectID] = model
        ids[model.id] = message.objectID
        return model
    }
}

// MARK: - ConsoleStoryViewModel

private final class MessageViewModel {
    let id = UUID()
    let index: Int
    var text = NSAttributedString()
    var isDirty = true
    
    init(index: Int) {
        self.index = index
    }
}

// MARK: - Helpers

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
    return formatter
}()

#if DEBUG
@available(iOS 13.0, *)
struct ConsoleStoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsoleStoryView(viewModel: .init(store: .mock, toolbar: .init(), details: .init(), mode: .init()))
                .previewLayout(.fixed(width: 700, height: 1200))
        }
    }
}
#endif
