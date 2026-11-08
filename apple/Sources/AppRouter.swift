import SwiftUI

enum EcrinDestination: String, CaseIterable, Identifiable {
    case home
    case atelier
    case memoryOS
    case einstein
    case nova
    case organic
    case fusion
    case verso
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "ÉCRIN"
        case .atelier: return "Atelier IA"
        case .memoryOS: return "MemoryOS"
        case .einstein: return "Einstein"
        case .nova: return "NOVA"
        case .organic: return "Organic"
        case .fusion: return "Fusion"
        case .verso: return "Verso"
        case .search: return "Recherche"
        case .settings: return "Réglages"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "cube"
        case .atelier: return "sparkles.rectangle.stack"
        case .memoryOS: return "square.stack.3d.up"
        case .einstein: return "sparkles"
        case .nova: return "lightbulb"
        case .organic: return "leaf"
        case .fusion: return "square.on.square"
        case .verso: return "viewfinder"
        case .search: return "magnifyingglass"
        case .settings: return "slider.horizontal.3"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var destination: EcrinDestination = .home

    func navigate(to destination: EcrinDestination) {
        self.destination = destination
    }

    func recenter() {
        destination = .home
    }
}
