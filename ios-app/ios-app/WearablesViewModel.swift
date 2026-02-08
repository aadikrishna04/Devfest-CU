import Combine
import MWDATCore
import SwiftUI

class WearablesViewModel: ObservableObject {
    @Published var registrationState: RegistrationState
    @Published var devices: [DeviceIdentifier]
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let wearables: WearablesInterface
    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.registrationState = wearables.registrationState
        self.devices = wearables.devices

        registrationTask = Task { @MainActor in
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }

        deviceStreamTask = Task { @MainActor in
            for await devices in wearables.devicesStream() {
                self.devices = devices
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    @MainActor
    func connectGlasses() {
        guard registrationState != .registering else { return }
        Task {
            do {
                try await wearables.startRegistration()
            } catch let error as RegistrationError {
                NSLog("[FirstAidCoach] RegistrationError: \(error)")
                showError("RegistrationError: \(error)")
            } catch {
                NSLog("[FirstAidCoach] Unknown error: \(type(of: error)) — \(error)")
                showError("\(type(of: error)): \(error)")
            }
        }
    }

    @MainActor
    func disconnectGlasses() {
        Task {
            do {
                try await wearables.startUnregistration()
            } catch let error as UnregistrationError {
                showError(error.description)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    @MainActor
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    @MainActor
    func dismissError() {
        showError = false
        errorMessage = ""
    }
}
