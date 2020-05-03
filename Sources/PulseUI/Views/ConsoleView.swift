// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)
import UIKit

struct ConsoleView: View {
    @ObservedObject var model: ConsoleViewModel

    @State private var isShowingShareSheet = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationView {
            List {
                VStack {
                    SearchBar(title: "Search \(model.messages.count) messages", text: $model.searchText)
                    Spacer(minLength: 12)
                    ConsoleQuickFiltersView(onlyErrors: $model.onlyErrors, isShowingSettings: $isShowingSettings)
                }.padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                ForEach(model.messages, id: \.objectID) { message in
                    NavigationLink(destination: ConsoleMessageDetailsView(model: .init(message: message))) {
                        ConsoleMessageViewListItem(searchCriteria: self.$model.searchCriteria, message: message)
                    }
                }
            }
            .navigationBarTitle(Text("Console"))
            .navigationBarItems(trailing:
                ShareButton {
                    self.isShowingShareSheet = true
                }
                .sheet(isPresented: $isShowingShareSheet) {
                    ShareView(activityItems: [try! self.model.prepareForSharing()])
                }
            )
            .sheet(isPresented: $isShowingSettings) {
                ConsoleSettingsView(model: self.model, isPresented:  self.$isShowingSettings)
            }
        }
    }
}

struct ConsoleMessageViewListItem: View {
    @Binding var searchCriteria: ConsoleSearchCriteria
    let message: MessageEntity
    @State private var isShowingShareSheet = false

    var body: some View {
        ConsoleMessageView(model: .init(message: message))
            // TODO: create a ViewModel for a share sheet
            .contextMenu {
                Button(action: {
                    self.isShowingShareSheet = true
                }) {
                    Text("Share")
                    Image(uiImage: UIImage(systemName: "square.and.arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .black, scale: .medium))!)
                }
                Button(action: {
                    UIPasteboard.general.string = self.message.text
                }) {
                    Text("Copy Message")
                    Image(uiImage: UIImage(systemName: "doc.on.doc", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .black, scale: .medium))!)
                }
                Button(action: {
                    let filter = ConsoleSearchFilter(text: self.message.system, kind: .system, relation: .equals)
                    self.searchCriteria.filters.append(filter)
                }) {
                    Text("Focus System \'\(message.system)\'")
                    Image(systemName: "eye")
                }
                Button(action: {
                    let filter = ConsoleSearchFilter(text: self.message.system, kind: .system, relation: .doesNotEqual)
                    self.searchCriteria.filters.append(filter)
                }) {
                    Text("Hide System \'\(message.system)\'")
                    Image(systemName: "eye.slash")
                }.foregroundColor(.red)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareView(activityItems: [self.message.text])
        }
    }
}
#endif

#if os(macOS)
struct ConsoleView: View {
    @ObservedObject var model: ConsoleViewModel

    var body: some View {
        VStack {
            HSplitView {
                NavigationView {
                    List(model.messages, id: \.objectID) { message in
                        NavigationLink(destination: self.detailsView(message: message)) {
                            ConsoleMessageView(model: .init(message: message))
                        }
                    }
                    .frame(minWidth: 320, minHeight: 480)
                }
            }
        }
    }

    private func detailsView(message: MessageEntity) -> some View {
        ConsoleMessageDetailsView(model: .init(message: message))
            .frame(minWidth: 320, minHeight: 480)
    }
}
#endif

struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleView(model: ConsoleViewModel(logger: mockLogger))
            ConsoleView(model: ConsoleViewModel(logger: mockLogger))
                .environment(\.colorScheme, .dark)
        }
    }
}
