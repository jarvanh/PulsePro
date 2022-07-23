//
//// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

struct PinButton: View {
    @ObservedObject var viewModel: PinButtonViewModel
    var isTextNeeded: Bool = true

    var body: some View {
        Button(action: viewModel.togglePin) {
            if isTextNeeded {
                Text(viewModel.isPinned ? "Remove Pin" : "Pin")
            }
            Image(systemName: viewModel.isPinned ? "pin.slash" : "pin")
        }
    }
}

@available(iOS 14.0, tvOS 14.0, *)
struct PinButton2: View {
    @ObservedObject var viewModel: PinButtonViewModel

    var body: some View {
        Button(action: viewModel.togglePin) {
            Label(viewModel.isPinned ? "Remove Pin" : "Pin", systemImage: viewModel.isPinned ? "pin.slash" : "pin")
        }
    }
}

#if os(watchOS)
@available(iOS 14.0, tvOS 14.0, *)
struct PinButton3: View {
    @ObservedObject var viewModel: PinButtonViewModel

    var body: some View {
        Button(action: viewModel.togglePin) {
            VStack(spacing: 4) {
                Image(systemName: viewModel.isPinned ? "pin.slash" : "pin")
                    .foregroundColor(.blue)
                Text(viewModel.isPinned ? "Remove Pin" : "Pin")
                    .font(.caption2)
            }.frame(height: 42)
        }
    }
}
#endif

#if os(iOS)
extension UIAction {
    static func makePinAction(with viewModel: PinButtonViewModel) -> UIAction {
        UIAction(
            title: viewModel.isPinned ? "Remove Pin" : "Pin",
            image: UIImage(systemName: viewModel.isPinned ? "pin.slash" : "pin"),
            handler: { _ in viewModel.togglePin() }
        )
    }
}

extension UIContextualAction {
    static func makePinAction(with viewModel: PinButtonViewModel) -> UIContextualAction {
        let action = UIContextualAction(
            style: .normal,
            title: viewModel.isPinned ? "Remove Pin" : "Pin",
            handler: { _,_,_  in viewModel.togglePin() }
        )
        action.backgroundColor = .systemBlue
        action.image = UIImage(systemName: viewModel.isPinned ? "pin.slash" : "pin")
        return action
    }
}

final class PinIndicatorView: UIImageView {
    private var viewModel: PinButtonViewModel?
    private var cancellables: [AnyCancellable] = []

    init() {
        super.init(image: pinImage)
        self.tintColor = .systemPink
    }

    func bind(viewModel: PinButtonViewModel) {
        self.viewModel = viewModel
        viewModel.$isPinned.sink { [weak self] isPinned in
            guard let self = self else { return }
            self.isHidden = !isPinned
        }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let pinImage: UIImage = {
    let image = UIImage(systemName: "pin")
    return image?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1)) ?? UIImage()
}()
#endif

struct PinView: View {
    @ObservedObject var viewModel: PinButtonViewModel
    let font: Font

    var body: some View {
        if viewModel.isPinned {
            Image(systemName: "pin")
                .font(font)
                .foregroundColor(.secondary)
        }
    }
}

final class PinButtonViewModel: ObservableObject {
    @Published private(set) var isPinned = false
    private let message: LoggerMessageEntity?
    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, message: LoggerMessageEntity) {
        self.store = store
        self.message = message
        self.subscribe()
    }

    init(store: LoggerStore, request: LoggerNetworkRequestEntity) {
        self.store = store
        self.message = request.message
        self.subscribe()
    }

    private func subscribe() {
        guard let message = message else { return } // Should never happen
        message.publisher(for: \.isPinned).sink { [weak self] in
            guard let self = self else { return }
            self.isPinned = $0
        }.store(in: &cancellables)
    }

    func togglePin() {
        guard let message = message else { return } // Should never happen
        store.togglePin(for: message)
    }
}

protocol Pinnable {
    var pinViewModel: PinButtonViewModel { get }
}
