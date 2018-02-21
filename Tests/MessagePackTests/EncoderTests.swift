import Foundation
import XCTest
@testable import MessagePack

/**
 * Tests encoding Codable objects into MessagePack.
 */

class EncoderTests: XCTestCase {

    static var allTests = {
        return [
            // Single values
            ("testEncodeInvalidValues", testEncodeInvalidValues),
            ("testEncodeSingleValue", testEncodeSingleValue),
            ("testEncodeNumbers", testEncodeNumbers),
            ("testEncodeBool", testEncodeBool),
            ("testEncodeURL", testEncodeURL),
            ("testEncodeData", testEncodeData),
            ("testEncodeDate", testEncodeDate),
            // Unkeyed
            ("testEncodeSingleValueArrays", testEncodeSingleValueArrays),
            ("testEncodeNestedArrays", testEncodeNestedArrays),
            ("testEncodeMapArray", testEncodeMapArray),
            ("testEncodeMixedArray", testEncodeMixedArray),
            ("testEncodeInvalidArray", testEncodeInvalidArray),
            // Keyed
            ("testEncodeMaps", testEncodeMaps),
            ("testEncodeNestedMap", testEncodeNestedMap),
            ("testEncodeSuperMap", testEncodeSuperMap),
            ("testEncodeInvalidMap", testEncodeInvalidMap)
        ]
    }()


    // MARK: - Single Values

    /**
     * Tests that encoding invalid values fails.
     */

    func testEncodeInvalidValues() {

        let encoder = MessagePackEncoder()

        do {

            _ = try encoder.encode(Empty())
            XCTFail("`Empty` does not encode anything, thus encoding should fail.")

        } catch {}

    }

    /**
     * Tests encoding single values.
     */

    func testEncodeSingleValue() throws {

        let encoder = MessagePackEncoder()

        let encodedNil = try encoder.encode(Optional<String>.none)
        XCTAssertEqual(encodedNil, Data([0xc0]))

        let encodedString = try encoder.encode("MessagePack")
        XCTAssertEqual(encodedString, Data([0xab, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x50, 0x61, 0x63, 0x6b]))

        let encodedDouble = try encoder.encode(Double(-120.5))
        XCTAssertEqual(encodedDouble, Data([0xcb, 0xc0, 0x5e, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00]))

        let encodedFloat = try encoder.encode(Float(250))
        XCTAssertEqual(encodedFloat, Data([0xca, 0x43, 0x7a, 0x00, 0x00]))

    }

    /**
     * Tests encoding numbers
     */

    func testEncodeNumbers() throws {

        let encoder = MessagePackEncoder()

        // Int

        let encodedInt = try encoder.encode(Int(-105))
        XCTAssertEqual(encodedInt, Data([0xd0, 0x97]))

        let encodedInt8 = try encoder.encode(Int8(-69))
        XCTAssertEqual(encodedInt8, Data([0xd0, 0xbb]))

        let encodedInt16 = try encoder.encode(Int16(-1234))
        XCTAssertEqual(encodedInt16, Data([0xd1, 0xfb, 0x2e]))

        let encodedInt32 = try encoder.encode(Int32(-123456789))
        XCTAssertEqual(encodedInt32, Data([0xd2, 0xf8, 0xa4, 0x32, 0xeb]))

        #if arch(x86_64) || arch(arm64)
            let encodedInt64 = try encoder.encode(Int64(-123456789987654321))
            XCTAssertEqual(encodedInt64, Data([0xd3, 0xfe, 0x49, 0x64, 0xb4, 0x1f, 0xad, 0x05, 0x4f]))
        #endif

        // UInt

        let encodedUInt = try encoder.encode(UInt(654))
        XCTAssertEqual(encodedUInt, Data([0xcd, 0x02, 0x8e]))

        let encodedUInt8 = try encoder.encode(UInt8(69))
        XCTAssertEqual(encodedUInt8, Data([0x45]))

        let encodedUInt16 = try encoder.encode(UInt16(1234))
        XCTAssertEqual(encodedUInt16, Data([0xcd, 0x04, 0xd2]))

        let encodedUInt32 = try encoder.encode(UInt32(123456789))
        XCTAssertEqual(encodedUInt32, Data([0xce, 0x07, 0x5b, 0xcd, 0x15]))

        #if arch(x86_64) || arch(arm64)
            let encodedUInt64 = try encoder.encode(UInt64(1234567890987654321))
            XCTAssertEqual(encodedUInt64, Data([0xcf, 0x11, 0x22, 0x10, 0xf4, 0xb1, 0x6c, 0x1c, 0xb1]))
        #endif

    }

    /**
     * Tests encoding booleans.
     */

    func testEncodeBool() throws {

        let encoder = MessagePackEncoder()

        let encodedTrue = try encoder.encode(true)
        XCTAssertEqual(encodedTrue, Data([0xc3]))

        let encodedFalse = try encoder.encode(false)
        XCTAssertEqual(encodedFalse, Data([0xc2]))

    }

    /**
     * Tests encoding URLs.
     */

    func testEncodeURL() throws {

        let relativeURL = URL(string: "msgpack", relativeTo: URL(string: "https://github.com")!)!
        let absoluteURL = URL(string: "https://github.com/msgpack")!

        let encoder = MessagePackEncoder()
        let expectedURLData = pack(.string("https://github.com/msgpack"))

        let encodedRelativeURL = try encoder.encode(relativeURL)
        let encodedAbsoluteURL = try encoder.encode(absoluteURL)

        XCTAssertEqual(encodedRelativeURL, expectedURLData)
        XCTAssertEqual(encodedAbsoluteURL, expectedURLData)

    }

    /**
     * Tests encoding binary data.
     */

    func testEncodeData() throws {

        let encoder = MessagePackEncoder()
        let secretData = Data(base64Encoded: "kXgsOgHLb1Z9XValPiaWAQ==")!

        let encodedSecret = try encoder.encode(secretData)
        XCTAssertEqual(encodedSecret, Data([0xc4, 16] + secretData))

    }

    /**
     * Tests encoding dates with different formats.
     */

    func testEncodeDate() throws {

        let date = Date(timeIntervalSince1970: 69_000)
        let messagePackEncoder = MessagePackEncoder()

        // Milliseconds

        let millisecondsEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .millisecondsSince1970)
        try millisecondsEncoder.encode(date)
        XCTAssertEqual(millisecondsEncoder.container, .singleValue(.int(69_000_000)))

        messagePackEncoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedMilliseconds = try messagePackEncoder.encode(date)
        XCTAssertEqual(encodedMilliseconds, Data([0xce, 0x04, 0x1c, 0xdb, 0x40]))

        // Seconds

        let secondsEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .secondsSince1970)
        try secondsEncoder.encode(date)
        XCTAssertEqual(secondsEncoder.container, .singleValue(.int(69_000)))

        messagePackEncoder.dateEncodingStrategy = .secondsSince1970
        let encodedSeconds = try messagePackEncoder.encode(date)
        XCTAssertEqual(encodedSeconds, Data([0xce, 0x00, 0x01, 0x0d, 0x88]))

        // Custom Function

        let customDateEncoder: (Date) throws -> Int64 = {
            Int64($0.hashValue)
        }

        let customEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .custom(customDateEncoder))
        try customEncoder.encode(date)
        XCTAssertEqual(customEncoder.container, .singleValue(.int(Int64(date.hashValue))))

        // Custom Formatter

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.pmSymbol = "Post Meridiem"

        let formatterEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .dateFormatter(formatter))
        try formatterEncoder.encode(date)

        XCTAssertEqual(formatterEncoder.container, .singleValue(.string("1/1/70, 7:10 Post Meridiem")))

        // Deferred to Date

        let deferredEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .deferredToDate)
        try deferredEncoder.encode(date)

        XCTAssertEqual(deferredEncoder.container, .singleValue(.double(date.timeIntervalSinceReferenceDate)))

        // ISO

        let isoEncoder = MessagePackStructureEncoder(userInfo: [:], dateEncodingStrategy: .iso8601)
        try isoEncoder.encode(date)
        XCTAssertEqual(isoEncoder.container, .singleValue(.string("1970-01-01T19:10:00Z")))

    }

    // MARK: - Unkeyed

    /**
     * Tests encoding arrays of single values.
     */

    func testEncodeSingleValueArrays() throws {

        let encoder = MessagePackEncoder()

        let strings: StringArray = ["Message", "Pack"]
        let encodedStrings = try encoder.encode(strings)
        XCTAssertEqual(encodedStrings, Data([0x92, 0xa7, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0xa4, 0x50, 0x61, 0x63, 0x6b]))

        let bools = TruthTable()
        let encodedBools = try encoder.encode(bools)
        XCTAssertEqual(encodedBools, Data([0x93, 0xc3, 0xc2, 0xc0]))

        let numberList = NumberList()
        let encodedNumbers = try encoder.encode(numberList)
        XCTAssertEqual(encodedNumbers, Data([0x9c, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0xca, 0x41, 0x28, 0x00, 0x00, 0xcb, 0x40, 0x27, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))

        let stringsArray = ["Message", "Pack"]
        let encodedStringArray = try encoder.encode(stringsArray)
        XCTAssertEqual(encodedStringArray, encodedStrings)

    }

    /**
     * Tests encoding nested arrays
     */

    func testEncodeNestedArrays() throws {

        let encoder = MessagePackEncoder()

        // With default implementation

        let strings = [["Message", "Pack"], ["JavaScript", "Object", "Notation"]]
        let encodedStrings = try encoder.encode(strings)

        XCTAssertEqual(encodedStrings, Data([0x92, 0x92, 0xa7, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0xa4, 0x50, 0x61, 0x63, 0x6b, 0x93, 0xaa, 0x4a, 0x61, 0x76, 0x61, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0xa6, 0x4f, 0x62, 0x6a, 0x65, 0x63, 0x74, 0xa8, 0x4e, 0x6f, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e]))

        // Using nested containers

        let nestedStrings: NestedArray = [["Message", "Pack"], ["JavaScript", "Object", "Notation"]]
        let encodedNestedStrings = try encoder.encode(nestedStrings)
        XCTAssertEqual(encodedNestedStrings, encodedStrings)

    }

    /**
     * Tests encoding an array of objects.
     */

    func testEncodeMapArray() throws {

        let encoder = MessagePackEncoder()

        // With default implementation

        let planets = [Planet.mercury, Planet.venus, Planet.earth, Planet.mars]
        let encodedPlanets = try encoder.encode(planets)

        let decodedPlanets = try unpack(encodedPlanets).value
        XCTAssertEqual(decodedPlanets.count, 4)

        // Using nested containers

        let telluricPlanets = TelluricPlanets()
        let encodedTelluricPlanets = try encoder.encode(telluricPlanets)
        XCTAssertEqual(encodedTelluricPlanets, encodedPlanets)

    }

    /**
     * Tries encoding an array with mixed types.
     */

    func testEncodeMixedArray() throws {

        let encoder = MessagePackEncoder()

        // Board

        let boardMembers: [Person] = [
            Person(name: "Arthur D. Levinson, Ph. D.", position: "Chairman of the Board, Apple"),
            Person(name: "James A. Bell", position: "Former CFO and Corporate President, The Boeing Company"),
            Person(name: "Albert Gore Jr.", position: "Former Vice President of the United States"),
        ]

        let board = Department(name: "Board", employees: boardMembers, parentDepartment: nil)

        // Execs

        let execMembers: [Person] = [
            Person(name: "Tim Cook", position: "CEO"),
            Person(name: "Katherine Adams", position: "Senior VP and General Counsel"),
            Person(name: "Angela Ahrendts", position: "Senior VP Retail"),
            Person(name: "Eddy Cue", position: "VP Internet Services")
        ]

        let exec = Department(name: "Exec. Committee", employees: execMembers, parentDepartment: board)

        // Encode and check values

        let encodedHierarchy = try encoder.encode(exec)
        let decodedHierarchy = try unpack(encodedHierarchy).value

        print(encodedHierarchy.base64EncodedString())

        XCTAssertEqual(decodedHierarchy.count, 3) // info, super, employees

        let decodedBoard = decodedHierarchy.arrayValue?[1].arrayValue
        XCTAssertEqual(decodedBoard?.count, 2) // info, employees
        XCTAssertEqual(decodedBoard?[1].count, boardMembers.count)

        let decodedExec = decodedHierarchy.arrayValue?[2].arrayValue
        XCTAssertEqual(decodedExec?.count, execMembers.count)

    }

    /**
     * Tests that encoding an invalid array fails.
     */

    func testEncodeInvalidArray() {

        let encoder = MessagePackEncoder()
        let emptys = [Empty(), Empty()]

        do {

            _ = try encoder.encode(emptys)
            XCTFail("Encoding an array of empty objects should not succeed.")

        } catch {}

    }

    // MARK: - Keyed

    /**
     * Tests encoding simple maps.
     */

    func testEncodeMaps() throws {

        let encoder = MessagePackEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        // Booleans

        var truthTable = TruthTable()
        truthTable.encodingStrategy = .keyed

        let encodedBooleans = try encoder.encode(truthTable)
        let decodedBooleans = try unpack(encodedBooleans).value.dictionaryValue

        XCTAssertEqual(decodedBooleans?[.string("yes")], .bool(true))
        XCTAssertEqual(decodedBooleans?[.string("no")], .bool(false))
        XCTAssertEqual(decodedBooleans?[.string("none")], .nil)

        // Numbers

        var numbers = NumberList()
        numbers.encodingStrategy = .keyed

        let encodedNumbers = try encoder.encode(numbers)
        let decodedNumbers = try unpack(encodedNumbers).value.dictionaryValue

        XCTAssertEqual(decodedNumbers?[.string("int")], .int(0))
        XCTAssertEqual(decodedNumbers?[.string("int8")], .int(1))
        XCTAssertEqual(decodedNumbers?[.string("int16")], .int(2))
        XCTAssertEqual(decodedNumbers?[.string("int32")], .int(3))
        XCTAssertEqual(decodedNumbers?[.string("int64")], .int(4))

        XCTAssertEqual(decodedNumbers?[.string("uint")], .int(5))
        XCTAssertEqual(decodedNumbers?[.string("uint8")], .int(6))
        XCTAssertEqual(decodedNumbers?[.string("uint16")], .int(7))
        XCTAssertEqual(decodedNumbers?[.string("uint32")], .int(8))
        XCTAssertEqual(decodedNumbers?[.string("uint64")], .int(9))

        XCTAssertEqual(decodedNumbers?[.string("float")], .float(10.5))
        XCTAssertEqual(decodedNumbers?[.string("double")], .double(11.5))

        // Planet

        let earth = Planet.earth
        let moon = Satellite.moon

        let encodedEarth = try encoder.encode(earth)

        let decodedEarth = try unpack(encodedEarth).value.dictionaryValue
        let decodedMoon = decodedEarth?[.string("satellites")]?.arrayValue?[0].dictionaryValue

        XCTAssertEqual(decodedEarth?[.string("name")], .string(earth.name))
        XCTAssertEqual(decodedEarth?[.string("isTelluric")], .bool(true))
        XCTAssertEqual(decodedEarth?[.string("radius")], .double(earth.radius))

        XCTAssertEqual(decodedMoon?[.string("name")], .string(moon.name))
        XCTAssertEqual(decodedMoon?[.string("hasWater")], .bool(false))

        // Parent Identifier

        let id = Identifier(uuid: UUID(), parentUUID: UUID())
        let encodedIdentifier = try encoder.encode(id)
        let decodedIdentifier = try unpack(encodedIdentifier).value.dictionaryValue

        XCTAssertEqual(decodedIdentifier?[.string("uuid")], .string(id.uuid.uuidString))
        XCTAssertEqual(decodedIdentifier?[.string("super")], .string(id.parentUUID!.uuidString))

    }

    /**
     * Tests encoding a map with nested data.
     */

    func testEncodeNestedMap() throws {

        let encoder = MessagePackEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        // Sample Data

        let tweetDate = Date()
        let replyDate = tweetDate.addingTimeInterval(69)

        let a2 = User(name: "Alex Akers", username: "a2")
        let _alexaubry = User(name: "Alexis Aubry", username: "_alexaubry")
        let panda = User(name: "Panda", username: "panda")

        let tweet = Tweet(text: "🐼", date: tweetDate, user: a2, likes: [_alexaubry, panda])
        let reply = Tweet(text: "Pandamazing", date: replyDate, user: _alexaubry, parentTweet: tweet, likes: [a2])

        // Encode Data

        let encodedTweet = try encoder.encode(reply)

        let decodedReply = try unpack(encodedTweet).value.dictionaryValue
        let decodedOriginalTweet = decodedReply?["parentTweet"]?.dictionaryValue
        let decodedReplyUser = decodedReply?["user"]?.dictionaryValue
        let decodedTweetUser = decodedOriginalTweet?["user"]?.dictionaryValue

        // Verify results

        XCTAssertEqual(decodedReply?[.string("text")], .string("Pandamazing"))
        XCTAssertNotNil(decodedReply?[.string("parentTweet")])
        XCTAssertNil(decodedReply?[.string("super")])
        XCTAssertEqual(decodedReply?[.string("date")], .int(Int64(replyDate.timeIntervalSince1970) * 1000))

        XCTAssertEqual(decodedOriginalTweet?[.string("text")], .string("🐼"))
        XCTAssertNil(decodedOriginalTweet?[.string("parentTweet")])
        XCTAssertNil(decodedOriginalTweet?[.string("super")])
        XCTAssertEqual(decodedOriginalTweet?[.string("date")], .int(Int64(tweetDate.timeIntervalSince1970) * 1000))

        XCTAssertEqual(decodedReplyUser?[.string("name")], .string("Alexis Aubry"))
        XCTAssertEqual(decodedReplyUser?[.string("user_name")], .string("_alexaubry"))

        XCTAssertEqual(decodedTweetUser?[.string("name")], .string("Alex Akers"))
        XCTAssertEqual(decodedTweetUser?[.string("user_name")], .string("a2"))

    }

    /**
     * Tests encoding a map with its super map.
     */

    func testEncodeSuperMap() throws {

        let encoder = MessagePackEncoder()

        // Sample data

        let _alexaubry = User(name: "Alexis Aubry", username: "_alexaubry")
        let news = List(owner: _alexaubry, name: "News", parentList: nil)
        let frenchNews = List(owner: _alexaubry, name: "French News", parentList: news)

        // Encode

        let encodedList = try encoder.encode(frenchNews)

        let decodedFrenchNews = try unpack(encodedList).value.dictionaryValue
        let decodedFrenchOwner = decodedFrenchNews?[.string("owner")]?.dictionaryValue

        let encodedNews = decodedFrenchNews?["super"]?.dictionaryValue
        let decodedNewsOwner = encodedNews?[.string("owner")]?.dictionaryValue

        // Verify results

        XCTAssertEqual(decodedFrenchNews?[.string("name")], .string("French News"))
        XCTAssertNotNil(decodedFrenchNews?[.string("super")])
        XCTAssertEqual(decodedFrenchOwner?[.string("name")], .string("Alexis Aubry"))
        XCTAssertEqual(decodedFrenchOwner?[.string("user_name")], .string("_alexaubry"))

        XCTAssertEqual(encodedNews?[.string("name")], .string("News"))
        XCTAssertNil(encodedNews?[.string("super")])
        XCTAssertEqual(decodedNewsOwner?[.string("name")], .string("Alexis Aubry"))
        XCTAssertEqual(decodedNewsOwner?[.string("user_name")], .string("_alexaubry"))

    }

    /**
     * Tests that encoding an invalid dictionary fails.
     */

    func testEncodeInvalidMap() {

        let encoder = MessagePackEncoder()
        let dictionary = ["empty": Empty()]

        do {

            _ = try encoder.encode(dictionary)
            XCTFail("Encoding a dictionary with empty objects should not succeed.")

        } catch {}

    }

}
