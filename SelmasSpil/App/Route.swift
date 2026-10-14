import Foundation

/// Alle skærme man kan navigere til. Holdes som værdier, så navigation kan gemmes/genskabes.
enum Route: Hashable {
    case world
    case house(UUID)
    case characters
    case characterBuilder(UUID)
    case parents
    case importDrawing
    case library
    case settings
}
