import XCTest
@testable import F4Core

final class SignalStickerPackTests: XCTestCase {
    private let id = "0123456789abcdef0123456789abcdef"
    private let key = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"

    func testReadsThePackLink() throws {
        let pack = try XCTUnwrap(SignalStickerPack(url: URL(string: "https://signal.art/addstickers/#pack_id=\(id)&pack_key=\(key)")!))
        XCTAssertEqual(pack.id, id)
        XCTAssertEqual(pack.key, key)
        XCTAssertEqual(pack.manifestURL.absoluteString, "https://cdn-ca.signal.org/stickers/\(id)/manifest.proto")
        XCTAssertEqual(pack.stickerURL(7).absoluteString, "https://cdn-ca.signal.org/stickers/\(id)/full/7")
    }

    func testIgnoresOtherLinks() {
        XCTAssertNil(SignalStickerPack(url: URL(string: "https://signal.art/addstickers/#pack_id=\(id)")!))
        XCTAssertNil(SignalStickerPack(url: URL(string: "https://example.com/addstickers/#pack_id=\(id)&pack_key=\(key)")!))
        XCTAssertNil(SignalStickerPack(url: URL(string: "https://signal.art/addstickers/#pack_id=xyz&pack_key=\(key)")!))
    }

    /// Encrypted like Signal does (HKDF-SHA256 "Sticker Pack", AES-256-CBC,
    /// HMAC-SHA256), with Python's cryptography package.
    func testDecryptsAndReadsTheManifest() throws {
        let pack = try XCTUnwrap(SignalStickerPack(url: URL(string: "https://signal.art/addstickers/#pack_id=\(id)&pack_key=\(key)")!))
        let encrypted = Data(hex: "6465666768696a6b6c6d6e6f70717273f0c368ce2794a2af3fdb615d26739644bb6c8b0a849514027fc46c5ff595fde7a186da71b661fd18a874ed3a5b99a15b19972305d272d01bf1843c2a3a8227755dc04c6b0c575f2a2fe6071b4af6f4f3")
        let manifest = try SignalStickerPack.manifest(from: pack.decrypt(encrypted))
        XCTAssertEqual(manifest, SignalStickerPack.Manifest(title: "Boris", author: "Fé", stickers: [0, 7]))
    }

    func testRejectsATamperedFile() throws {
        let pack = try XCTUnwrap(SignalStickerPack(url: URL(string: "https://signal.art/addstickers/#pack_id=\(id)&pack_key=\(key)")!))
        var encrypted = Data(hex: "6465666768696a6b6c6d6e6f70717273f0c368ce2794a2af3fdb615d26739644bb6c8b0a849514027fc46c5ff595fde7a186da71b661fd18a874ed3a5b99a15b19972305d272d01bf1843c2a3a8227755dc04c6b0c575f2a2fe6071b4af6f4f3")
        encrypted[20] ^= 1
        XCTAssertThrowsError(try pack.decrypt(encrypted)) { XCTAssertEqual($0 as? SignalStickerPack.Failure, .badMAC) }
    }
}

private extension Data {
    init(hex: String) {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self = data
    }
}
