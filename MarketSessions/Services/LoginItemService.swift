import Foundation
import ServiceManagement

enum LoginItemState: Hashable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool { self == .enabled }
}

@MainActor
protocol LoginItemServicing {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class LoginItemService: LoginItemServicing {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var state: LoginItemState {
        Self.map(service.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                openSystemSettings()
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                return
            }
        } else {
            switch service.status {
            case .enabled, .requiresApproval:
                try service.unregister()
            case .notRegistered, .notFound:
                return
            @unknown default:
                return
            }
        }
    }

    private func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    nonisolated static func map(_ status: SMAppService.Status) -> LoginItemState {
        switch status {
        case .enabled:
            .enabled
        case .notRegistered:
            .disabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }
}
