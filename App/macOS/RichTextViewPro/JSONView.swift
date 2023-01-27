// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

struct JSONView: View {
    @ObservedObject var viewModel: JSONViewModel
    @State private var isSpinnerHidden = true
    @AppStorage("jqVertical") private var isJQVertical = true
    
    var body: some View {
        makeJSONViewer()
            .onReceive(viewModel.$jqProcessing.debounce(for: 0.33, scheduler: RunLoop.main, options: nil).removeDuplicates()) {
                self.isSpinnerHidden = !$0
            }
    }
    
    @ViewBuilder
    private func makeJSONViewer() -> some View {
        if isJQVertical {
            VSplitView {
                makeJSONMainView()
                if !viewModel.isJQHidden {
                    jqView
                }
            }
        } else {
            HSplitView {
                makeJSONMainView()
                if !viewModel.isJQHidden {
                    jqView
                }
            }
        }
    }
    
    @ViewBuilder
    private func makeJSONMainView() -> some View {
        RichTextViewPro(
            viewModel: viewModel.textModel,
            content: .response,
            onTerminalTapped: { viewModel.isJQHidden.toggle() }
        )
            .frame(minWidth: 200, idealWidth: 500, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    var jqView: some View {
        VStack(spacing: 0) {
            Divider()
            RichTextViewPro(viewModel: viewModel.jqOutput, isSearchBarHidden: true, content: .response)
            Divider()
            HStack {
                TextField("Expression", text: $viewModel.jqExpression)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 80, idealWidth: 320, maxWidth: 320)
                if !isSpinnerHidden {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .transformEffect(.init(scaleX: 0.5, y: 0.5).translatedBy(x: 15, y: 15))
                        .frame(width: 20, height: 20, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                        .padding(.leading, 1)
                } else {
                    Rectangle()
                        .hidden()
                        .frame(width: 20, height: 20)
                        .padding(.leading, 1)
                }
                Spacer()
                Button(action: { isJQVertical.toggle() }, label: {
                    Image(systemName: isJQVertical ? "square.split.2x1" : "square.split.1x2")
                }).buttonStyle(PlainButtonStyle())
            }
            .padding([.leading, .trailing], 6)
            .frame(height: 34)
        }
        .frame(minWidth: 200, idealWidth: 500, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center)
    }

    #warning("rewrite using PulseUI.ImageView")
    @ViewBuilder
    private func makeImageViewer(image: NSImage) -> some View {
        Text("Placeholder")
    }
    
    @ViewBuilder
    private func makePlainTextView(text: NSAttributedString) -> some View {
        RichTextViewPro(viewModel: .init(string: text), content: .response)
            .frame(minWidth: 200, idealWidth: 500, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Preview

#if DEBUG
struct JSONView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JSONView(viewModel: mockModel)
                .previewDisplayName("Light")
                .environment(\.colorScheme, .light)

            JSONView(viewModel: mockModel)
                .previewDisplayName("Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)


        }
    }
}

private let mockModel = JSONViewModel(json: MockJSON.allPossibleValues)

private let mockHTML = """
<!DOCTYPE html>
<html>
<body>

<h1>My First Heading</h1>
<p>My first paragraph.</p>

</body>
</html>
""".data(using: .utf8)!
#endif


private extension Data {
    var localizedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
