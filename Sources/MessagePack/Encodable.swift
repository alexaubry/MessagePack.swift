import Foundation

/// Encodes objects to the MessagePack format.
public final class MessagePackEncoder {

    /// A dictionary you use to customize the encoding process by providing contextual information.
    public var userInfo: [CodingUserInfoKey : Any] = [:]

    // MARK: - Encoding Dates

    /// How to encode dates.
    public enum DateEncodingStrategy {

        /// Use the default format from the `Date` class.
        case deferredToDate

        /// Encode the date to an ISO-8601 string.
        @available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *)
        case iso8601

        /// Encode the date as the time interval since 1970, in seconds.
        case secondsSince1970

        /// Encode the date as the time interval since 1970, in milliseconds.
        case millisecondsSince1970

        /// Use the specified date formatter.
        case dateFormatter(DateFormatter)

        /// A custom date encoder.
        case custom((Date) throws -> Encodable)
        
    }

    /// The strategy used when encoding dates as part of a MessagePack object.
    public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate

    // MARK: - Encoding

    /// Encodes an object to the MessagePack format.
    ///
    /// - parameter object: The object to encode to MessagePack.
    /// - returns: A Data object containing the MessagePack representation of the object.

    public func encode(_ object: Encodable) throws -> Data {

        let structureEncoder = MessagePackStructureEncoder(userInfo: userInfo, dateEncodingStrategy: dateEncodingStrategy)

        /*** I- Encode the structure of the value ***/

        // Date, Data and URL Encodable implementations are not compatible with MessagePack.

        if let date = object as? Date {
            var singleValueStorage = structureEncoder.singleValueContainer()
            try singleValueStorage.encode(date)

        } else if let url = object as? URL {
            var singleValueStorage = structureEncoder.singleValueContainer()
            try singleValueStorage.encode(url)

        } else if let data = object as? Data {
            var singleValueStorage = structureEncoder.singleValueContainer()
            try singleValueStorage.encode(data)

        } else {
            // If the object is encodable, encode to the structure encoder.
            try object.encode(to: structureEncoder)
        }

        /*** II- Get the encoded MessagePack value and pack it ***/

        guard let topLevelContainer = structureEncoder.container else {
            let errorContext =  EncodingError.Context(codingPath: structureEncoder.codingPath,
                                                      debugDescription: "Top-level object did not encode any values.")
            throw EncodingError.invalidValue(object, errorContext)
        }

        let messagePackValue: MessagePackValue

        switch topLevelContainer {
        case .singleValue(let storage):
            messagePackValue = storage

        case .unkeyed(let storage):
            messagePackValue = .array(storage.copy())

        case .keyed(let storage):
            messagePackValue = .map(storage.copy())
        }

        return pack(messagePackValue)

    }

}

// MARK: - Structure Encoder

/// A class that serializes the structure of an encodable object.
class MessagePackStructureEncoder: Encoder {

    /// The encoder's storage.
    var container: CodingContainer?

    /// The path to the current point in encoding.
    var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    var userInfo: [CodingUserInfoKey : Any]

    // MARK: Options

    /// The date encoding strategy.
    let dateEncodingStrategy: MessagePackEncoder.DateEncodingStrategy

    // MARK: Initialization

    init(userInfo: [CodingUserInfoKey : Any], dateEncodingStrategy: MessagePackEncoder.DateEncodingStrategy) {
        self.container = nil
        self.codingPath = []
        self.userInfo = userInfo
        self.dateEncodingStrategy = dateEncodingStrategy
    }

    // MARK: Coding Path Operations

    /// Indicates whether encoding has failed at the current key path.
    var containsFailures: Bool {
        return codingPath.isEmpty == false
    }

    ///
    /// Asserts that it is possible for the encoded value to request a new container.
    ///
    /// The value can only request one container. If the storage contains more containers than the
    /// encoder has coding keys, it means that the value is trying to request more than one container
    /// which is invalid.
    ///

    func assertCanRequestNewContainer() {
        precondition(container == nil, "You cannot request multiple containers to encode the same object.")
        precondition(containsFailures == false, "Cannot encode to a new container, because an error occured while encoding a value at path '\(codingPath)'.")
    }

    ///
    /// Performs the given closure with the given key pushed onto the end of the current coding path.
    ///
    /// - parameter key: The key to push. May be nil for unkeyed containers.
    /// - parameter work: The work to perform with the key in the path.
    ///
    /// If the `work` fails, `key` will be left in the coding path, which indicates a failure and
    /// prevents requesting new containers.
    ///

    fileprivate func with<T>(pushedKey key: CodingKey, _ work: () throws -> T) rethrows -> T {
        self.codingPath.append(key)
        let ret: T = try work()
        codingPath.removeLast()
        return ret
    }

    // MARK: Containers

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        assertCanRequestNewContainer()
        let storage = CodingDictionaryStorage()
        container = .keyed(storage)
        let keyedContainer = MessagePackKeyedEncodingContainer<Key>(referencing: self, codingPath: codingPath, wrapping: storage)
        return KeyedEncodingContainer(keyedContainer)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        assertCanRequestNewContainer()
        let storage = CodingArrayStorage()
        container = .unkeyed(storage)
        return MessagePackUnkeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: storage)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        assertCanRequestNewContainer()
        return self
    }

}

// MARK: - Single Value Container

extension MessagePackStructureEncoder: SingleValueEncodingContainer {

    ///
    /// Asserts that a single value can be encoded into the container (i.e. that no value has
    /// previously been encoded.
    ///

    func assertCanEncodeSingleValue() {

        switch container {
        case .singleValue?:
            preconditionFailure("Attempt to encode multiple values in a single value container.")

        case .keyed?, .unkeyed?:
            preconditionFailure("You cannot request multiple containers to encode the same object.")

        case nil:
            return
        }

    }

    func encodeNil() {
        assertCanEncodeSingleValue()
        container = .singleValue(.nil)
    }

    func encode(_ value: Bool) {
        assertCanEncodeSingleValue()
        container = .singleValue(.bool(value))
    }

    func encode(_ value: Int) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: Int8) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: Int16) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: Int32) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: Int64) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: UInt) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: UInt8) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: UInt16) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: UInt32) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: UInt64) {
        assertCanEncodeSingleValue()
        container = .singleValue(.int(Int64(value)))
    }

    func encode(_ value: Float) {
        assertCanEncodeSingleValue()
        container = .singleValue(.float(value))
    }

    func encode(_ value: Double) {
        assertCanEncodeSingleValue()
        container = .singleValue(.double(value))
    }

    func encode(_ value: String) {
        assertCanEncodeSingleValue()
        container = .singleValue(.string(value))
    }

    func encode<T: Encodable>(_ value: T) throws  {
        assertCanEncodeSingleValue()
        container = try encodeToDetachedContainer(value)
    }

}

// MARK: - Single Value Parsers

extension MessagePackStructureEncoder {

    /// Encodes the value in a temporary container.
    func encodeToDetachedContainer<T: Encodable>(_ value: T) throws -> CodingContainer? {

        var encodedValue: Encodable = value

        // If the value is a URL, encode the absolute String.
        if let url = value as? URL {
            return .singleValue(.string(url.absoluteString))
        }

        // If the value is a Data, encode the value into a MessagePack representation.
        if let data = value as? Data {
            return .singleValue(.binary(data))
        }

        // If the value is a Date, encode the value appropriate for the strategy.
        if let date = value as? Date {
            encodedValue = try encodableDateValue(for: date)
        }

        // Encode the value to a detached container
        let tempEncoder = MessagePackStructureEncoder(userInfo: userInfo, dateEncodingStrategy: dateEncodingStrategy)
        try encodedValue.encode(to: tempEncoder)

        return tempEncoder.container

    }

    /// Returns the value to encode for the specified date.
    func encodableDateValue(for date: Date) throws -> Encodable {

        switch dateEncodingStrategy {
        case .deferredToDate:
            return date

        case .iso8601:

            if #available(iOS 10, macOS 10.12, tvOS 10, watchOS 3, *) {

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = .withInternetDateTime

                let dateString = formatter.string(from: date)
                return dateString

            } else {
                let errorContext = EncodingError.Context(codingPath: codingPath,
                                                         debugDescription: "ISO-8601 date encoding is not available on this platform.")
                throw EncodingError.invalidValue(date, errorContext)
            }

        case .millisecondsSince1970:
            return Int64(date.timeIntervalSince1970) * 1000

        case .secondsSince1970:
            return Int64(date.timeIntervalSince1970)

        case let .dateFormatter(formatter):
            return formatter.string(from: date)

        case .custom(let formatter):
            return try formatter(date)
        }

    }

}

// MARK: - Unkeyed Container

private class MessagePackUnkeyedEncodingContainer: UnkeyedEncodingContainer {

    /// A reference to the encoder we're writing to.
    let encoder: MessagePackStructureEncoder

    /// A reference to the container storage we're writing to.
    let storage: CodingArrayStorage

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey]

    // MARK: Initialization

    init(referencing encoder: MessagePackStructureEncoder, codingPath: [CodingKey], wrapping storage: CodingArrayStorage) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.storage = storage
    }

    // MARK: Encoding

    var count: Int {
        return storage.count
    }

    func encodeNil() {
        storage.append(.nil)
    }

    func encode(_ value: Bool) {
        storage.append(.bool(value))
    }

    func encode(_ value: Int) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: Int8) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: Int16) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: Int32) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: Int64) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: UInt) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: UInt8) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: UInt16) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: UInt32) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: UInt64) {
        storage.append(.int(Int64(value)))
    }

    func encode(_ value: Float) {
        storage.append(.float(value))
    }

    func encode(_ value: Double) {
        storage.append(.double(value))
    }

    func encode(_ value: String) {
        storage.append(.string(value))
    }

    func encode<T: Encodable>(_ value: T) throws  {

        // Encode the value in a temporary container and insert the contents into the array storage

        try encoder.with(pushedKey: MessagePackCodingKey.index(count)) {

            guard let newContainer = try self.encoder.encodeToDetachedContainer(value) else {
                let errorContext =  EncodingError.Context(codingPath: self.encoder.codingPath,
                                                          debugDescription: "Object did not encode any values.")
                throw EncodingError.invalidValue(value, errorContext)
            }

            switch newContainer {
            case .singleValue(let value):
                storage.append(value)
            case .unkeyed(let arrayStorage):
                storage.append(.array(arrayStorage.copy()))
            case .keyed(let dictionaryStorage):
                storage.append(.map(dictionaryStorage.copy()))
            }

        }

    }

    // MARK: Nested Containers

    /// The nested unkeyed containers referencing this container.
    var nestedUnkeyedContainers: [Int: CodingArrayStorage] = [:]

    /// The nested keyed containers referencing this container.
    var nestedKeyedContainers: [Int: CodingDictionaryStorage] = [:]

    /// The encoder to encode `super` into the container.
    var currentSuperEncoder: MessagePackReferencingEncoder? = nil

    /// The number of items inside the container.
    var endIndex: Int {
        let nestedCount = storage.count + nestedUnkeyedContainers.count + nestedKeyedContainers.count
        return currentSuperEncoder == nil ? nestedCount : nestedCount + 1
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {

        let nestedStorage = CodingDictionaryStorage()
        nestedKeyedContainers[endIndex] = nestedStorage

        let keyedContainer = MessagePackKeyedEncodingContainer<NestedKey>(referencing: encoder, codingPath: codingPath, wrapping: nestedStorage)
        return KeyedEncodingContainer(keyedContainer)

    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {

        let nestedStorage = CodingArrayStorage()
        nestedUnkeyedContainers[endIndex] = nestedStorage

        return MessagePackUnkeyedEncodingContainer(referencing: encoder, codingPath: codingPath, wrapping: nestedStorage)
    }

    func superEncoder() -> Encoder {
        precondition(currentSuperEncoder == nil, "You can only encode `super` one time.")
        currentSuperEncoder = MessagePackReferencingEncoder(referencing: encoder, at: endIndex)
        return currentSuperEncoder!
    }

    // MARK: Deinitialization

    deinit {

        var nestedValues: [Int: MessagePackValue] = [:]

        // When the Encodable object finished encoding, add the contents of the nested containers
        // to the array reference stored by the structure encoder

        for (index, nestedStorage) in nestedUnkeyedContainers {
            nestedValues[index] = MessagePackValue.array(nestedStorage.copy())
        }

        for (index, nestedStorage) in nestedKeyedContainers {
            nestedValues[index] = MessagePackValue.map(nestedStorage.copy())
        }

        // Add the contents of the super encoder

        if let (superValue, superReference) = currentSuperEncoder?.commitChanges() {
            guard case let .array(index) = superReference else {
                fatalError("Unkeyed containers should not produce a keyed super encoder. Please file a bug report.")
            }

            nestedValues[index] = superValue
        }

        // Sort and add to the storage

        let sortedNestedValues = nestedValues.sorted { $0.key < $1.key }

        for (index, nestedValue) in sortedNestedValues {
            storage.insert(nestedValue, at: index)
        }

    }

}

// MARK: - Keyed Encoding Container

///
/// A keyed encoding container for objects.
///

private class MessagePackKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    /// A reference to the encoder we're writing to.
    let encoder: MessagePackStructureEncoder

    /// A reference to the container storage we're writing to.
    let storage: CodingDictionaryStorage

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey]

    // MARK: Initialization

    init(referencing encoder: MessagePackStructureEncoder, codingPath: [CodingKey], wrapping storage: CodingDictionaryStorage) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.storage = storage
    }

    // MARK: Encoding

    func encodeNil(forKey key: K) throws {
        storage.setValue(.nil, forKey: key)
    }

    func encode(_ value: Bool, forKey key: K) throws {
        storage.setValue(.bool(value), forKey: key)
    }

    func encode(_ value: Int, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: Int8, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: Int16, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: Int32, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: Int64, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: UInt, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: UInt8, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: UInt16, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: UInt32, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: UInt64, forKey key: K) throws {
        storage.setValue(.int(Int64(value)), forKey: key)
    }

    func encode(_ value: Float, forKey key: K) throws {
        storage.setValue(.float(value), forKey: key)
    }

    func encode(_ value: Double, forKey key: K) throws {
        storage.setValue(.double(value), forKey: key)
    }

    func encode(_ value: String, forKey key: K) throws {
        storage.setValue(.string(value), forKey: key)
    }

    func encode<T: Encodable>(_ value: T, forKey key: K) throws {

        try encoder.with(pushedKey: MessagePackCodingKey.string(key.stringValue)) {

            guard let newContainer = try self.encoder.encodeToDetachedContainer(value) else {
                let errorContext =  EncodingError.Context(codingPath: self.encoder.codingPath,
                                                          debugDescription: "Top-level object did not encode any values.")
                throw EncodingError.invalidValue(value, errorContext)
            }

            switch newContainer {
            case .singleValue(let value):
                storage.setValue(value, forKey: key)
            case .unkeyed(let value):
                storage.setValue(.array(value.copy()), forKey: key)
            case .keyed(let value):
                storage.setValue(.map(value.copy()), forKey: key)
            }

        }

    }

    // MARK: Nested Containers

    var nestedUnkeyedContainers: [String: CodingArrayStorage] = [:]
    var nestedKeyedContainers: [String: CodingDictionaryStorage] = [:]
    var currentSuperEncoder: MessagePackReferencingEncoder? = nil

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> {
        let dictionary = CodingDictionaryStorage()
        nestedKeyedContainers[key.stringValue] = dictionary
        let container = MessagePackKeyedEncodingContainer<NestedKey>(referencing: encoder, codingPath: codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let array = CodingArrayStorage()
        nestedUnkeyedContainers[key.stringValue] = array
        return MessagePackUnkeyedEncodingContainer(referencing: encoder, codingPath: codingPath, wrapping: array)
    }

    func superEncoder() -> Encoder {
        precondition(currentSuperEncoder == nil, "You can only encode `super` one time.")
        currentSuperEncoder = MessagePackReferencingEncoder(referencing: encoder, at: MessagePackCodingKey.super)
        return currentSuperEncoder!
    }

    func superEncoder(forKey key: K) -> Encoder {
        precondition(currentSuperEncoder == nil, "You can only encode `super` one time.")
        currentSuperEncoder = MessagePackReferencingEncoder(referencing: encoder, at: key)
        return currentSuperEncoder!
    }

    // MARK: Deinitialization

    deinit {

        // When the Encodable object finished encoding, add the contents of the nested containers
        // to the dictionary reference stored by the structure encoder

        for (key, nestedStorage) in nestedUnkeyedContainers {
            storage.setValue(.array(nestedStorage.copy()), forKey: MessagePackCodingKey(stringValue: key))
        }

        for (key, nestedStorage) in nestedKeyedContainers {
            storage.setValue(.map(nestedStorage.copy()), forKey: MessagePackCodingKey(stringValue: key))
        }

        // Add the contents of the super encoder

        if let (superValue, superReference) = currentSuperEncoder?.commitChanges() {
            guard case let .dictionary(key) = superReference else {
                fatalError("Keyed containers should not produce an unkeyed super encoder. Please file a bug report.")
            }

            storage.setValue(superValue, forKey: key)
        }

    }

}

// MARK: - Reference

///
/// A structure encoder that references the contents of a sub-encoder.
///

private class MessagePackReferencingEncoder: MessagePackStructureEncoder {

    /// The kind of refrence.
    enum Reference {

        /// The encoder references an array at the given index.
        case array(Int)

        /// The encoder references a dictionary at the given key.
        case dictionary(CodingKey)

    }

    // MARK: Properties

    /// The encoder we're referencing.
    let encoder: MessagePackStructureEncoder

    /// The container reference itself.
    let reference: Reference

    // MARK: Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    fileprivate init(referencing encoder: MessagePackStructureEncoder, at index: Int) {
        self.encoder = encoder
        self.reference = .array(index)
        super.init(userInfo: encoder.userInfo, dateEncodingStrategy: encoder.dateEncodingStrategy)
        codingPath.append(MessagePackCodingKey.index(index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(referencing encoder: MessagePackStructureEncoder, at key: CodingKey) {
        self.encoder = encoder
        self.reference = .dictionary(key)
        super.init(userInfo: encoder.userInfo, dateEncodingStrategy: encoder.dateEncodingStrategy)
        self.codingPath.append(key)
    }

    // MARK: Options

    override var containsFailures: Bool {
        return codingPath.count != (encoder.codingPath.count + 1)
    }

    // MARK: Deinitialization

    /// Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    func commitChanges() -> (value: MessagePackValue, reference: Reference) {

        let value: MessagePackValue
        precondition(container != nil, "Super encoder did not encode any value.")

        switch container! {
        case .singleValue(let storage):
            value = storage

        case .unkeyed(let storage):
            value = .array(storage.copy())

        case .keyed(let storage):
            value = .map(storage.copy())
        }

        return (value, reference)

    }

}
