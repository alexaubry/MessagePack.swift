import Foundation
import XCTest
@testable import MessagePack

class FloatTests: XCTestCase {
    static var allTests = {
        return [
            ("testPack", testPack),
            ("testUnpack", testUnpack),
        ]
    }()

    let packed = Data([0xca, 0x40, 0x48, 0xf5, 0xc3])
    let packedNan = Data([0xca, 0x7f, 0xc0, 0x00, 0x00])

    func testPack() {
        XCTAssertEqual(pack(.float(3.14)), packed)
    }

    func testPackNan() {
        XCTAssertEqual(pack(.float(.nan)), packedNan)
    }

    func testUnpack() {
        let unpacked = try? unpack(packed)
        XCTAssertEqual(unpacked?.value, .float(3.14))
        XCTAssertEqual(unpacked?.remainder.count, 0)
    }

    func testUnpackNan() {
        let unpacked = try? unpack(packedNan)
        XCTAssertTrue(unpacked?.value.floatValue?.isNaN == true)
        XCTAssertEqual(unpacked?.remainder.count, 0)
    }
}
