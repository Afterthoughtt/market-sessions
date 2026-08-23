import Foundation
import ServiceManagement

enum LoginItemState: Hashable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool { self == .enabled }

    var detail: String? {
        switch self {
        case .enabled, .disabled:
            nil
        case .requiresApproval:
            "Approval is required in Login Items."
        case .unavailable:
            "Launch at Login is unavailable."
        }
    }
}

@MainActor
protocol LoginItemServicing {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
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

    func openSystemSettings() {
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
