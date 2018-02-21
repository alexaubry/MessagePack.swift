import Foundation

// MARK: Coding Container

/// A container for data serialization.
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

// MARK: - Coding Path Error Handling

/// A protocol for objects that perform work with a coding path.

protocol CodingPathWorkPerforming: class {
    var codingPath: [CodingKey] { get set }
    var initialCodingPathLength: Int { get }
}

extension CodingPathWorkPerforming {

    /// Checks if previous failures keep up from performing a coding path work.
    func assertCanPerformWork() {
        precondition(codingPath.count == initialCodingPathLength,
                     "Cannot perform work new value because previous error was ignored.")
    }

    ///
    /// Performs the work for the value at the given key.
    ///
    /// The key will be pushed onto the end of the current coding path. If the `work` fails, `key`
    /// will be left in the coding path, which indicates a failure and prevents encoding more values.
    ///
    /// - parameter key: The key to the value we're working with.
    /// - parameter work: The work to perform with the key in the path.
    ///

    func with<T>(pushedKey key: CodingKey, _ work: () throws -> T) rethrows -> T {
        self.codingPath.append(key)
        let result: T = try work()
        codingPath.removeLast()
        return result
    }

}

// MARK: - Array Storage

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

    /// Creates a storage from an existing array.
    init(_ array: [MessagePackValue]) {
        self.array = array
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

    /// Returns the value at the given index
    func value(at index: Int) -> MessagePackValue? {

        guard array.indices.contains(index) else {
            return nil
        }

        return array[index]

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

    /// Creates a storage from an existing dictionary.
    init(_ dictionary: [MessagePackValue: MessagePackValue]) {
        self.dictionary = dictionary
    }

    // MARK: Dictionary Interaction

    /// Access and update the element keyed with the specified coding key.
    subscript(key: CodingKey) -> MessagePackValue? {
        get {
            return self.dictionary[key.storageKey]
        }
        set {
            self.dictionary[key.storageKey] = newValue
        }
    }

    // MARK: Contents

    var keys: Dictionary<MessagePackValue, MessagePackValue>.Keys {
        return dictionary.keys
    }

    /// A copy of the contents of the dictionary storage.
    func copy() -> [MessagePackValue: MessagePackValue] {
        return dictionary
    }

}

// MARK: - MessagePack Storage Keys

/// A key for MessagePack objects.
enum MessagePackCodingKey: CodingKey, Hashable {

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

    static func == (lhs: MessagePackCodingKey, rhs: MessagePackCodingKey) -> Bool {

        switch (lhs, rhs) {
        case let (.string(lString), .string(rString)):
            return lString == rString

        case let (.index(lIndex), .index(rIndex)):
            return lIndex == rIndex

        case (.super, .super):
            return true

        default:
            return false
        }

    }

    var hashValue: Int {
        return stringValue.hashValue
    }

}

extension CodingKey {

    /// Returns the dictionary key appropriate for nested storage references.
    var nestedStorageKey: MessagePackCodingKey {

        if let intValue = self.intValue {
            return .index(intValue)
        } else {
            return .string(self.stringValue)
        }

    }

    /// Returns the dictionary key appropriate for the coding key.
    var storageKey: MessagePackValue {

        if let intValue = self.intValue {
            return .int(Int64(intValue))
        } else {
            return .string(self.stringValue)
        }

    }

}
