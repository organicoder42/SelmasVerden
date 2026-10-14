import Foundation

/// Hele spillets tilstand: figurer, huse og gaden. Gemmes som én JSON-fil.
struct SaveGame: Codable, Sendable {
    var version: Int
    var characters: [GameCharacter]
    var houses: [House]
    /// Den fælles udendørs-scene mellem husene.
    var street: Room
    var updatedAt: Date

    static let currentVersion = 1

    init(version: Int = SaveGame.currentVersion,
         characters: [GameCharacter] = [],
         houses: [House] = [],
         street: Room = Room(name: "Gaden", kind: .street, level: 0),
         updatedAt: Date = Date()) {
        self.version = version
        self.characters = characters
        self.houses = houses
        self.street = street
        self.updatedAt = updatedAt
    }

    static var empty: SaveGame { SaveGame() }

    func character(id: UUID) -> GameCharacter? { characters.first { $0.id == id } }
    func house(id: UUID) -> House? { houses.first { $0.id == id } }

    mutating func upsert(_ character: GameCharacter) {
        if let i = characters.firstIndex(where: { $0.id == character.id }) {
            characters[i] = character
        } else {
            characters.append(character)
        }
        updatedAt = Date()
    }

    mutating func upsert(_ house: House) {
        if let i = houses.firstIndex(where: { $0.id == house.id }) {
            houses[i] = house
        } else {
            houses.append(house)
        }
        updatedAt = Date()
    }

    mutating func deleteCharacter(id: UUID) {
        characters.removeAll { $0.id == id }
        // Fjern også figuren fra alle rum, så der ikke står "spøgelser".
        for h in houses.indices {
            for r in houses[h].rooms.indices {
                houses[h].rooms[r].placements.removeAll { $0.content.characterID == id }
            }
        }
        street.placements.removeAll { $0.content.characterID == id }
        updatedAt = Date()
    }

    mutating func deleteHouse(id: UUID) {
        houses.removeAll { $0.id == id }
        updatedAt = Date()
    }
}
