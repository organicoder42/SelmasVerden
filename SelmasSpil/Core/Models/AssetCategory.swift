import Foundation

/// Alle typer tegninger spillet kender.
/// Rå-værdierne bruges i JSON-manifestet og som enum i AI-klassificeringen,
/// så de må ikke ændres uden migrering.
enum AssetCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    // Figur-dele
    case body, hair, eyes, mouth, nose, ears, eyebrows, beard, handLeft, handRight
    // Tøj - hver del for sig, aldrig hele outfits
    case top, bottom, dress, jacket, shoes, socks, hat, glasses, bag, accessory
    // Møbler og inventar
    case furniture, decoration, plant, toy, food, vehicle, pet
    // Hus-dele
    case houseFacade, wall, floor, door, window, roof, fence, stairs
    // Udendørs
    case tree, flower, sky, ground, outdoorItem
    // Andet
    case pattern          // mønster-flise, bruges til at fylde områder på møbler/tøj
    case uiIcon           // håndtegnede knapper og ikoner til selve spillets brugerflade
    case fullCharacter    // en hel figur tegnet som ét - skal deles op i dele
    case unknown

    var id: String { rawValue }

    var group: AssetGroup {
        switch self {
        case .body, .hair, .eyes, .mouth, .nose, .ears, .eyebrows, .beard, .handLeft, .handRight, .fullCharacter:
            return .characterParts
        case .top, .bottom, .dress, .jacket, .shoes, .socks, .hat, .glasses, .bag, .accessory:
            return .clothing
        case .furniture, .decoration, .plant, .toy, .food, .vehicle, .pet:
            return .furniture
        case .houseFacade, .wall, .floor, .door, .window, .roof, .fence, .stairs:
            return .house
        case .tree, .flower, .sky, .ground, .outdoorItem:
            return .outdoor
        case .pattern:
            return .patterns
        case .uiIcon, .unknown:
            return .other
        }
    }

    /// Dansk navn vist i spillet.
    var danishName: String {
        switch self {
        case .body: return "Krop"
        case .hair: return "Hår"
        case .eyes: return "Øjne"
        case .mouth: return "Mund"
        case .nose: return "Næse"
        case .ears: return "Ører"
        case .eyebrows: return "Øjenbryn"
        case .beard: return "Skæg"
        case .handLeft: return "Venstre hånd"
        case .handRight: return "Højre hånd"
        case .top: return "Trøje"
        case .bottom: return "Bukser / nederdel"
        case .dress: return "Kjole"
        case .jacket: return "Jakke"
        case .shoes: return "Sko"
        case .socks: return "Strømper"
        case .hat: return "Hat / hue"
        case .glasses: return "Briller"
        case .bag: return "Taske"
        case .accessory: return "Smykker og pynt"
        case .furniture: return "Møbel"
        case .decoration: return "Dekoration"
        case .plant: return "Plante"
        case .toy: return "Legetøj"
        case .food: return "Mad"
        case .vehicle: return "Køretøj"
        case .pet: return "Kæledyr"
        case .houseFacade: return "Hus (set udefra)"
        case .wall: return "Væg / tapet"
        case .floor: return "Gulv"
        case .door: return "Dør"
        case .window: return "Vindue"
        case .roof: return "Tag"
        case .fence: return "Hegn"
        case .stairs: return "Trappe"
        case .tree: return "Træ"
        case .flower: return "Blomst"
        case .sky: return "Himmel"
        case .ground: return "Jord / græs"
        case .outdoorItem: return "Udendørs ting"
        case .pattern: return "Mønster"
        case .uiIcon: return "Knap / ikon"
        case .fullCharacter: return "Hel figur"
        case .unknown: return "Ved ikke"
        }
    }

    /// Hvis denne kategori kan sættes på en figur, hvilken plads fylder den så?
    var wearableSlot: WearableSlot? {
        WearableSlot(rawValue: rawValue)
    }

    /// Kan ting i denne kategori stilles ind i et rum eller en have?
    var isPlaceable: Bool {
        switch group {
        case .furniture, .outdoor: return true
        case .house: return self == .door || self == .window || self == .stairs || self == .fence
        default: return false
        }
    }

    /// Kan man farve og sætte mønstre på den?
    var isPaintableByDefault: Bool {
        switch self {
        case .pattern, .uiIcon, .sky, .ground, .unknown: return false
        default: return true
        }
    }

    /// Kategorier som en forælder kan vælge imellem i import-oversigten (sorteret pænt).
    static var selectable: [AssetCategory] {
        allCases.filter { $0 != .unknown }
    }
}

enum AssetGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case characterParts, clothing, furniture, house, outdoor, patterns, other
    var id: String { rawValue }

    var danishName: String {
        switch self {
        case .characterParts: return "Figur-dele"
        case .clothing: return "Tøj"
        case .furniture: return "Møbler og ting"
        case .house: return "Hus"
        case .outdoor: return "Udenfor"
        case .patterns: return "Mønstre"
        case .other: return "Andet"
        }
    }

    var categories: [AssetCategory] {
        AssetCategory.allCases.filter { $0.group == self }
    }
}

/// Pladser på en figur. Rækkefølgen af `zIndex` bestemmer hvad der ligger over hvad.
enum WearableSlot: String, Codable, CaseIterable, Identifiable, Sendable, CodingKeyRepresentable {
    case hair, eyes, eyebrows, nose, mouth, ears, beard, handLeft, handRight
    case socks, shoes, bottom, dress, top, jacket, hat, glasses, bag, accessory

    var id: String { rawValue }

    /// Tegne-rækkefølge. Kroppen er altid 0.
    var zIndex: Int {
        switch self {
        case .socks: return 10
        case .shoes: return 20
        case .bottom: return 30
        case .dress: return 40
        case .top: return 50
        case .jacket: return 60
        case .handLeft, .handRight: return 65
        case .ears: return 70
        case .eyes: return 80
        case .eyebrows: return 81
        case .nose: return 82
        case .mouth: return 83
        case .beard: return 84
        case .hair: return 90
        case .hat: return 100
        case .glasses: return 110
        case .bag: return 120
        case .accessory: return 130
        }
    }

    var isBodyPart: Bool {
        switch self {
        case .hair, .eyes, .eyebrows, .nose, .mouth, .ears, .beard, .handLeft, .handRight: return true
        default: return false
        }
    }

    var category: AssetCategory { AssetCategory(rawValue: rawValue) ?? .unknown }
    var danishName: String { category.danishName }

    /// Hvilke pladser kan ikke bæres samtidig (kjole vs. trøje+bukser).
    var conflicts: [WearableSlot] {
        switch self {
        case .dress: return [.top, .bottom]
        case .top, .bottom: return [.dress]
        default: return []
        }
    }
}
