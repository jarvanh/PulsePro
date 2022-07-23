// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(watchOS)
import WatchConnectivity

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isShowingFiltersView = false
    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false
    @State private var isRemoteLoggingLinkActive = false

    public init(store: LoggerStore = .default) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Button(action: viewModel.tranferStore) {
                Label(viewModel.fileTransferStatus.title, systemImage: "square.and.arrow.up")
            }.disabled(viewModel.fileTransferStatus.isButtonDisabled)
            if viewModel.store === RemoteLogger.shared.store {
                NavigationLink(destination: _RemoteLoggingSettingsView(viewModel: .shared)) {
                    Button(action: { isRemoteLoggingLinkActive = true }) {
                        Label("Remote Logging", systemImage: "network")
                    }
                }
            }
            Button(action: { isShowingFiltersView = true }) {
                Label("Quick Filters", systemImage: "line.horizontal.3.decrease.circle")
            }
            ConsoleMessagesForEach(store: viewModel.store, messages: viewModel.entities)
        }
        .navigationTitle("Console")
        .toolbar {
            ToolbarItemGroup {
                ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
                    .disabled(viewModel.entities.isEmpty)
                    .opacity(viewModel.entities.isEmpty ? 0.33 : 1)
                    .padding(.bottom, 4)
            }
        }
        .alert(item: $viewModel.fileTransferError) { error in
            Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
        }
        .sheet(isPresented: $isShowingFiltersView) {
            List(viewModel.quickFilters) { filter in
                Button(action: {
                    filter.action()
                    isShowingFiltersView = false
                }) {
                    Label(filter.title, systemImage: filter.imageName)
                        .foregroundColor(filter.title == "Reset" ? Color.red : nil)
                }
            }
        }
    }
}

private struct _RemoteLoggingSettingsView: View {
    let viewModel: RemoteLoggerSettingsViewModel

    var body: some View {
        Form {
            RemoteLoggerSettingsView(viewModel: viewModel)
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }
        }
    }
}
#endif
#endif
