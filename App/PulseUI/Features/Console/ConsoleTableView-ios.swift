// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import PulseCore
import CoreData
import Combine
import UIKit

final class ConsoleTableViewModel {
    let store: LoggerStore
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?
    var diff: CollectionDifference<NSManagedObjectID>?
    @Published var entities: [NSManagedObject] = []

    init(store: LoggerStore, searchCriteriaViewModel: ConsoleSearchCriteriaViewModel?) {
        self.store = store
        self.searchCriteriaViewModel = searchCriteriaViewModel
    }
}

struct ConsoleTableView<Header: View>: View {
    @ViewBuilder let header: () -> Header
    let viewModel: ConsoleTableViewModel
    let detailsViewModel: ConsoleDetailsRouterViewModel

    @State private var isDetailsLinkActive = false

    var body: some View {
        _ConsoleTableView(header: header, viewModel: viewModel, onSelected: {
            detailsViewModel.select($0)
            isDetailsLinkActive = true
        })
        .background(links)
    }

    @ViewBuilder
    private var links: some View {
        NavigationLink.programmatic(isActive: $isDetailsLinkActive) {
            ConsoleMessageDetailsRouter(viewModel: detailsViewModel)
        }
    }
}

/// Using this because of the following List issues:
///  - Reload performance issues
///  - NavigationLink popped when cell disappears
///  - List doesn't keep scroll position when reloaded
private struct _ConsoleTableView<Header: View>: UIViewControllerRepresentable {
    @ViewBuilder let header: () -> Header
    let viewModel: ConsoleTableViewModel
    let onSelected: (NSManagedObject) -> Void

    func makeUIViewController(context: Context) -> ConsoleTableViewController {
        let vc = ConsoleTableViewController(viewModel: viewModel)
        let header = self.header()
        if !(header is EmptyView) {
            vc.setHeaderView(header)
        }
        vc.onSelected = onSelected
        return vc
    }

    func updateUIViewController(_ uiViewController: ConsoleTableViewController, context: Context) {
        // Do nothing
    }
}

final class ConsoleTableViewController: UITableViewController {
    private let viewModel: ConsoleTableViewModel
    private var entities: [NSManagedObject] = []
    private var entityViewModels: [NSManagedObjectID: AnyObject] = [:]
    private var cancellables: [AnyCancellable] = []

    var onSelected: ((NSManagedObject) -> Void)?

    init(viewModel: ConsoleTableViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
        self.createView()
        self.bind(viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        tableView.register(ConsoleMessageTableCell.self, forCellReuseIdentifier: "ConsoleMessageTableCell")
        tableView.register(ConsoleNetworkRequestTableCell.self, forCellReuseIdentifier: "ConsoleNetworkRequestTableCell")

        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
    }

    private func bind(_ viewModel: ConsoleTableViewModel) {
        viewModel.$entities.sink { [weak self] entities in
            self?.display(entities)
        }.store(in: &cancellables)
    }

    private var isFirstDisplay = true

    private func display(_ entities: [NSManagedObject]) {
        self.entities = entities
        if let diff = viewModel.diff, !isFirstDisplay {
            viewModel.diff = nil
            tableView.apply(diff: diff)
        } else {
            tableView.reloadData()
        }
        isFirstDisplay = false
    }

    func setHeaderView<Header: View>(_ view: Header) {
        let header = UIHostingController(rootView: view).view
        header?.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        tableView.tableHeaderView = header
    }

    // MARK: - ViewModel

    func getEntityViewModel(at indexPath: IndexPath) -> AnyObject {
        let entity = entities[indexPath.row]
        if let viewModel = entityViewModels[entity.objectID] {
            return viewModel
        }
        let viewModel: AnyObject
        switch entity {
        case let message as LoggerMessageEntity:
            if let request = message.request {
                viewModel = ConsoleNetworkRequestViewModel(request: request, store: self.viewModel.store)
            } else {
                viewModel = ConsoleMessageViewModel(message: message, store: self.viewModel.store, searchCriteriaViewModel: self.viewModel.searchCriteriaViewModel)
            }
        case let request as LoggerNetworkRequestEntity:
            viewModel = ConsoleNetworkRequestViewModel(request: request, store: self.viewModel.store)
        default:
            fatalError("Invalid entity: \(entity)")
        }
        entityViewModels[entity.objectID] = viewModel
        return viewModel
    }

    // MARK: - UITableViewDelegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch getEntityViewModel(at: indexPath) {
        case let viewModel as ConsoleMessageViewModel:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleMessageTableCell", for: indexPath) as! ConsoleMessageTableCell
            cell.display(viewModel)
            return cell
        case let viewModel as ConsoleNetworkRequestViewModel:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleNetworkRequestTableCell", for: indexPath) as! ConsoleNetworkRequestTableCell
            cell.display(viewModel)
            return cell
        default:
            fatalError("Invalid viewModel: \(viewModel)")
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelected?(entities[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let pinViewModel = (getEntityViewModel(at: indexPath) as? Pinnable)?.pinViewModel else {
            return nil
        }
        let actions = UISwipeActionsConfiguration(actions: [
            .makePinAction(with: pinViewModel)
        ])
        actions.performsFirstActionWithFullSwipe = true
        return actions
    }
}

#endif
