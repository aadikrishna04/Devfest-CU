import MWDATCore
import SwiftUI

/// Invisible view that handles OAuth callback URLs from the Meta AI app
/// during DAT SDK registration and permission flows.
struct RegistrationView: View {
    @ObservedObject var viewModel: WearablesViewModel

    var body: some View {
        EmptyView()
            .onOpenURL { url in
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
                else {
                    return
                }
                Task {
                    do {
                        _ = try await Wearables.shared.handleUrl(url)
                    } catch let error as RegistrationError {
                        viewModel.showError(error.description)
                    } catch {
                        viewModel.showError(error.localizedDescription)
                    }
                }
            }
    }
}
