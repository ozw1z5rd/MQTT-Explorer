import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        if viewModel.connectionState.connected {
            TopicTreeView(viewModel: viewModel)
        } else {
            ConnectionSetupView(viewModel: viewModel)
        }
    }
}
