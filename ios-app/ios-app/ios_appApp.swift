import MWDATCamera
import MWDATCore
import SwiftUI

@main
struct ios_appApp: App {
    @StateObject private var viewModel: WearablesViewModel

    private let wearables: WearablesInterface
    @State private var configError: String?

    init() {
        var errorMsg: String? = nil
        do {
            try Wearables.configure()
        } catch {
            let msg = "SDK configure failed: \(error)"
            NSLog("[FirstAidCoach] \(msg)")
            errorMsg = msg
        }

        let wearables = Wearables.shared
        self.wearables = wearables
        self._viewModel = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
        self._configError = State(initialValue: errorMsg)
    }

    var body: some Scene {
        WindowGroup {
            MetaCameraView(wearables: wearables, viewModel: viewModel)
                .alert("SDK Configuration Error", isPresented: Binding(
                    get: { configError != nil },
                    set: { if !$0 { configError = nil } }
                )) {
                    Button("OK") { configError = nil }
                } message: {
                    Text(configError ?? "")
                }
                .alert("Error", isPresented: $viewModel.showError) {
                    Button("OK") { viewModel.dismissError() }
                } message: {
                    Text(viewModel.errorMessage)
                }

            RegistrationView(viewModel: viewModel)
        }
    }
}
