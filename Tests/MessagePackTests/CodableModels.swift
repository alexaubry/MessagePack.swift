import Foundation
import MessagePack

enum EncodingStrategy {
    case unkeyed, keyed
}

// MARK: Data Structures

/**
 * A structure that doesn't encode any data.
 */

struct Empty: Encodable {
    func encode(to encoder: Encoder) {}
}

/**
 * A structure that encodes an identifier and a parent.
 */

struct Identifier: Encodable {

    let uuid: UUID
    let parentUUID: UUID?

    enum CodingKeys: String, CodingKey {
        case uuid
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)

        if let parentUUID = parentUUID {
            let parentEncoder = container.superEncoder()
            try parentUUID.encode(to: parentEncoder)
        }

    }

}

/**
 * A structure that encodes true, false and nil.
 */

struct TruthTable: Encodable {

    var encodingStrategy: EncodingStrategy = .unkeyed

    enum CodingKeys: String, CodingKey {
        case yes, no, none
    }

    func encode(to encoder: Encoder) throws {

        switch encodingStrategy {
        case .keyed:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(true, forKey: .yes)
            try container.encode(false, forKey: .no)
            try container.encodeNil(forKey: .none)

        case .unkeyed:
            var container = encoder.unkeyedContainer()
            try container.encode(true)
            try container.encode(false)
            try container.encodeNil()
        }

    }

}

/**
 * An array of strings, that encodes the strings using an unkeyed container.
 */

struct StringArray: Encodable, ExpressibleByArrayLiteral {

    let strings: [String]

    init(arrayLiteral elements: String...) {
        self.strings = elements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for string in strings {
            try container.encode(string)
        }
    }

}

/**
 * A structure that encodes numbers of every MessagePack supported type.
 */

struct NumberList: Encodable {

    var encodingStrategy: EncodingStrategy = .unkeyed

    enum CodingKeys: String, CodingKey {
        case int, int8, int16, int32, int64
        case uint, uint8, uint16, uint32, uint64
        case float, double
    }

    func encode(to encoder: Encoder) throws {

        switch encodingStrategy {
        case .keyed:
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(Int(0), forKey: .int)
            try container.encode(Int8(1), forKey: .int8)
            try container.encode(Int16(2), forKey: .int16)
            try container.encode(Int32(3), forKey: .int32)
            try container.encode(Int64(4), forKey: .int64)

            try container.encode(UInt(5), forKey: .uint)
            try container.encode(UInt8(6), forKey: .uint8)
            try container.encode(UInt16(7), forKey: .uint16)
            try container.encode(UInt32(8), forKey: .uint32)
            try container.encode(UInt64(9), forKey: .uint64)

            try container.encode(Float(10.5), forKey: .float)
            try container.encode(Double(11.5), forKey: .double)

        case .unkeyed:

            var container = encoder.unkeyedContainer()

            try container.encode(Int(0))
            try container.encode(Int8(1))
            try container.encode(Int16(2))
            try container.encode(Int32(3))
            try container.encode(Int64(4))

            try container.encode(UInt(5))
            try container.encode(UInt8(6))
            try container.encode(UInt16(7))
            try container.encode(UInt32(8))
            try container.encode(UInt64(9))

            try container.encode(Float(10.5))
            try container.encode(Double(11.5))

        }

    }

}

/**
 * An array of arrays, that encodes its data using nested containers.
 */

struct NestedArray<Element: Encodable>: Encodable, ExpressibleByArrayLiteral {

    let arrays: [[Element]]

    init(arrayLiteral elements: [Element]...) {
        self.arrays = elements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        for array in arrays {
            var nestedContainer = container.nestedUnkeyedContainer()
            for element in array {
                try nestedContainer.encode(element)
            }
        }
    }

}

// MARK: - Planets

/**
 * A planet.
 */

struct Planet: Encodable {

    enum CodingKeys: String, CodingKey {
        case name, isTelluric, radius, satellites
    }

    let name: String
    let isTelluric: Bool
    let radius: Double
    let satellites: [Satellite]

    static let mercury = Planet(name: "Mercury", isTelluric: true, radius: 2439.7, satellites: [])
    static let venus = Planet(name: "Venus", isTelluric: true, radius: 6051.8, satellites: [])
    static let earth = Planet(name: "Earth", isTelluric: true, radius: 6378.1, satellites: [.moon])
    static let mars = Planet(name: "Mars", isTelluric: true, radius: 3389.5, satellites: [.phobos, .deimos])

}

/**
 * A natural sattelite.
 */

struct Satellite: Encodable {
    let name: String
    let hasWater: Bool

    static let moon = Satellite(name: "Moon", hasWater: false)
    static let phobos = Satellite(name: "Phobos", hasWater: false)
    static let deimos = Satellite(name: "Deimos", hasWater: false)
}

/**
 * A system of telluric planets. Encodes the planets with nested keyed encoders.
 */

struct TelluricPlanets: Encodable {

    func encode(to encoder: Encoder) throws {

        var container = encoder.unkeyedContainer()
        let planets = [Planet.mercury, Planet.venus, Planet.earth]

        for planet in planets {

            var planetContainer = container.nestedContainer(keyedBy: Planet.CodingKeys.self)

            try planetContainer.encode(planet.name, forKey: .name)
            try planetContainer.encode(planet.isTelluric, forKey: .isTelluric)
            try planetContainer.encode(planet.radius, forKey: .radius)
            try planetContainer.encode(planet.satellites, forKey: .satellites)

        }

        // Encode to a non-nested encoder.
        try container.encode(Planet.mars)

    }

}

// MARK: - Tweets

/**
 * A twitter user.
 */

struct User: Encodable {

    enum CodingKeys: String, CodingKey {
        case name, username = "user_name"
    }

    let name: String
    let username: String

}

/**
 * A tweet. Uses nested containers for encoding subdata.
 */

class Tweet: Encodable {

    let text: String
    let date: Date
    let user: User
    var parentTweet: Tweet?
    var likes: [User]

    enum CodingKeys: String, CodingKey {
        case text, date, user, parentTweet, likes
    }

    init(text: String, date: Date, user: User, parentTweet: Tweet? = nil, likes: [User]) {
        self.text = text
        self.date = date
        self.user = user
        self.parentTweet = parentTweet
        self.likes = likes
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(text, forKey: .text)
        try container.encode(date, forKey: .date)

        // User

        var userContainer = container.nestedContainer(keyedBy: User.CodingKeys.self, forKey: .user)
        try userContainer.encode(user.name, forKey: .name)
        try userContainer.encode(user.username, forKey: .username)

        // Parent

        if let parentTweet = parentTweet {
            let parentEncoder = container.superEncoder(forKey: .parentTweet)
            try parentTweet.encode(to: parentEncoder)
        }

        // Likes

        var likesContainer = container.nestedUnkeyedContainer(forKey: .likes)

        for userLike in likes {
            var userLikeContainer = likesContainer.nestedContainer(keyedBy: User.CodingKeys.self)
            try userLikeContainer.encode(userLike.name, forKey: .name)
            try userLikeContainer.encode(userLike.username, forKey: .username)
        }

    }

}

/**
 * A twitter list, where the parent is encoded inside a super encoder.
 */

class List: Encodable {

    let owner: User
    let name: String
    var parentList: List?

    enum CodingKeys: String, CodingKey {
        case owner, name
    }

    init(owner: User, name: String, parentList: List?) {
        self.owner = owner
        self.name = name
        self.parentList = parentList
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(owner, forKey: .owner)
        try container.encode(name, forKey: .name)

        // Parent list

        if let parentList = parentList {
            let parentListEncoder = container.superEncoder()
            try parentList.encode(to: parentListEncoder)
        }

    }

}

// MARK: - Work Department

/**
 * A person. Uses the default Codable implementation.
 */

struct Person: Encodable {

    let name: String
    let position: String

    enum CodingKeys: String, CodingKey {
        case name, position
    }

}

/**
 * A department in an entreprise. Encodes to an unkeyed container.
 */

class Department: Encodable {

    let name: String
    let employees: [Person]
    let parentDepartment: Department?

    enum CodingKeys: String, CodingKey {
        case name, hasParent
    }

    init(name: String, employees: [Person], parentDepartment: Department?) {
        self.name = name
        self.employees = employees
        self.parentDepartment = parentDepartment
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.unkeyedContainer()

        // Encode info
        
        var statusContainer = container.nestedContainer(keyedBy: Department.CodingKeys.self)
        try statusContainer.encode(name, forKey: .name)
        try statusContainer.encode(parentDepartment != nil, forKey: .hasParent)

        // Encode parent department

        if let parent = parentDepartment {
            let parentEncoder = container.superEncoder()
            try parent.encode(to: parentEncoder)
        }

        // Encode employees

        var employeesContainer = container.nestedUnkeyedContainer()

        for employee in employees {
            var employeeContainer = employeesContainer.nestedContainer(keyedBy: Person.CodingKeys.self)
            try employeeContainer.encode(employee.name, forKey: .name)
            try employeeContainer.encode(employee.position, forKey: .position)
        }

    }

}
