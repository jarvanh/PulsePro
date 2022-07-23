// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS)

public struct PinsView: View {
    @ObservedObject var viewModel: PinsViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    public init(store: LoggerStore = .default) {
        self.viewModel = PinsViewModel(store: store)
    }

    init(viewModel: PinsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contents
            .navigationBarTitle(Text("Pins"))
            .navigationBarItems(
                leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } },
                trailing:
                    Button(action: viewModel.removeAllPins) { Image(systemName: "trash") }
                    .disabled(viewModel.messages.isEmpty)
            )
    }

    @ViewBuilder
    private var contents: some View {
        if viewModel.messages.isEmpty {
            placeholder
                .navigationBarTitle(Text("Pins"))
        } else {
            ConsoleTableView(
                header: { EmptyView() },
                viewModel: viewModel.table,
                detailsViewModel: viewModel.details
            )
        }
    }

    private var placeholder: PlaceholderView {
        PlaceholderView(imageName: "pin.circle", title: "No Pins", subtitle: "Pin messages using the context menu or from the details page")
    }
}

#if DEBUG
struct PinsView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            PinsView(viewModel: .init(store: .mock))
            PinsView(viewModel: .init(store: .mock))
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif

#endif
