import Foundation

/// An encoding container.
enum CodingContainer: Equatable {

    /// A single value container associated with a single-value storage.
    case singleValue(MessagePackValue)

    /// An unkeyed value container associated with a reference to an array storage.
    case unkeyed(CodingArrayStorage)

    /// A keyed value container associated with a reference to a dictionary storage.
    case keyed(CodingDictionaryStorage)

    static func == (lhs: CodingContainer, rhs: CodingContainer) -> Bool {

        switch (lhs, rhs) {
        case let (.singleValue(lValue), .singleValue(rValue)):
            return lValue == rValue
        case let (.unkeyed(lArray), .unkeyed(rArray)):
            return lArray.array == rArray.array
        case let (.keyed(lMap), .keyed(rMap)):
            return lMap.dictionary == rMap.dictionary
        default:
            return false
        }

    }

}

// MARK: Array Storage

/// An object that holds a reference to an array. Use this class when you need an Array with
/// reference semantics.
class CodingArrayStorage {

    /// The underlying array object.
    fileprivate var array: [MessagePackValue]

    // MARK: Initialization

    /// Creates an empty array storage.
    init() {
        array = [MessagePackValue]()
    }

    // MARK: Array Interaction

    /// The number of elements in the Array.
    var count: Int {
        return array.count
    }

    /// Appends an element to the array.
    func append(_ element: MessagePackValue) {
        array.append(element)
    }

    /// Inserts a new element in the array.
    func insert(_ element: MessagePackValue, at index: Int) {
        array.insert(element, at: index)
    }

    // MARK: Contents

    /// A mutable copy of the contents of the array storage.
    func copy() -> [MessagePackValue] {
        return array
    }

}

// MARK: - Dictionary Storage

///
/// An object that holds a reference to a dictionary. Use this class when you need a Dictionary with
/// reference semantics.
///

class CodingDictionaryStorage {

    /// The underlying dictionary.
    fileprivate var dictionary: [MessagePackValue: MessagePackValue]

    // MARK: Initialization

    /// Creates an empty dictionary storage.
    init() {
        dictionary = [MessagePackValue: MessagePackValue]()
    }

    // MARK: Dictionary Interaction

    /// Sets or removes the value for the specified key.
    func setValue(_ value: MessagePackValue?, forKey key: CodingKey) {
        dictionary[.string(key.stringValue)] = value
    }

    // MARK: Contents

    /// A copy of the contents of the dictionary storage.
    func copy() -> [MessagePackValue: MessagePackValue] {
        return dictionary
    }

}

// MARK: - JSON Key

/// A key for MessagePack objects.
enum MessagePackCodingKey: CodingKey {

    /// A string key.
    case string(String)

    /// An index key.
    case index(Int)

    /// A string key for the object's superclass.
    case `super`

    /// The text value of the key.
    var stringValue: String {

        switch self {
        case .string(let string):
            return string
        case .index(let index):
            return "\(index)"
        case .super:
            return "super"
        }

    }

    /// The integer value of the key?
    var intValue: Int? {

        guard case let .index(idx) = self else {
            return nil
        }

        return idx

    }

    /// Creates a JSON key with an integer raw key.
    init(intValue: Int) {
        self = .index(intValue)
    }

    /// Creates a JSON key with a String raw key.
    init(stringValue: String) {
        self = .string(stringValue)
    }

}
