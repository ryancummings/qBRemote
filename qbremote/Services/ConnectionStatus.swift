import Foundation

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case connecting
    case connected
    case error(String)

    var color: String {
        switch self {
        case .connecting: return "orange"
        case .connected:  return "green"
        case .error:      return "red"
        }
    }

    var label: String {
        switch self {
        case .connecting:     return "Connecting…"
        case .connected:      return "Connected"
        case .error(let msg): return msg
        }
    }

    var systemImage: String {
        switch self {
        case .connecting: return "circle.dotted"
        case .connected:  return "checkmark.circle.fill"
        case .error:      return "exclamationmark.circle.fill"
        }
    }
}
