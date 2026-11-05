import CommonCrypto
import CryptoKit
import Foundation

/// A Signal sticker pack: Signal's packs are public and in an open format,
/// thousands of them listed on signalstickers.org, each one shared as a link
/// (`https://signal.art/addstickers/#pack_id=<32 hex>&pack_key=<64 hex>`).
/// The manifest and each sticker are files on Signal's CDN, encrypted with a
/// key derived from `pack_key` (HKDF-SHA256, then AES-256-CBC with an
/// HMAC-SHA256), as Signal's own apps do. Nothing here touches the network.
public struct SignalStickerPack: Equatable, Sendable {
    public let id: String
    public let key: String

    /// The pack a link points to, or nil when it is not a Signal pack link.
    public init?(url: URL) {
        guard let host = url.host?.lowercased(), host == "signal.art" || host == "www.signal.art",
              url.path.hasPrefix("/addstickers") else { return nil }
        // The ids are in the fragment ("#pack_id=...&pack_key=..."), or in
        // the query of some shared copies.
        let text = [url.fragment, url.query].compactMap { $0 }.joined(separator: "&")
        var values: [String: String] = [:]
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { values[parts[0]] = parts[1].lowercased() }
        }
        guard let id = values["pack_id"], let key = values["pack_key"],
              id.count == 32, key.count == 64, Self.isHex(id), Self.isHex(key) else { return nil }
        self.id = id
        self.key = key
    }

    public var manifestURL: URL {
        URL(string: "https://cdn-ca.signal.org/stickers/\(id)/manifest.proto")!
    }

    public func stickerURL(_ sticker: UInt32) -> URL {
        URL(string: "https://cdn-ca.signal.org/stickers/\(id)/full/\(sticker)")!
    }

    /// What the manifest says: the pack's title and its stickers.
    public struct Manifest: Equatable, Sendable {
        public var title: String
        public var author: String
        public var stickers: [UInt32]
    }

    public enum Failure: Error, Equatable {
        case badData
        case badMAC
    }

    /// Decrypts a file of the pack (the manifest or a sticker).
    public func decrypt(_ data: Data) throws -> Data {
        guard data.count >= 16 + 16 + 32, let master = Self.bytes(hex: key) else { throw Failure.badData }
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: master),
            salt: Data(count: 32),
            info: Data("Sticker Pack".utf8),
            outputByteCount: 64
        ).withUnsafeBytes { Data($0) }
        let aesKey = derived.prefix(32)
        let macKey = SymmetricKey(data: derived.suffix(32))
        let body = data.prefix(data.count - 32)
        let mac = data.suffix(32)
        guard HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: body, using: macKey) else { throw Failure.badMAC }
        let iv = body.prefix(16)
        let cipher = body.dropFirst(16)
        var output = Data(count: cipher.count + kCCBlockSizeAES128)
        var written = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            cipher.withUnsafeBytes { input in
                iv.withUnsafeBytes { ivBytes in
                    aesKey.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, keyBytes.count, ivBytes.baseAddress,
                            input.baseAddress, input.count, out.baseAddress, capacity, &written
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw Failure.badData }
        return output.prefix(written)
    }

    /// Reads a decrypted manifest (protobuf: 1 title, 2 author, 3 cover,
    /// 4 repeated sticker { 1 id, 2 emoji }).
    public static func manifest(from data: Data) throws -> Manifest {
        var reader = ProtoReader(Array(data))
        var manifest = Manifest(title: "", author: "", stickers: [])
        while let entry = try reader.next() {
            switch entry {
            case (1, .bytes(let bytes)): manifest.title = String(decoding: bytes, as: UTF8.self)
            case (2, .bytes(let bytes)): manifest.author = String(decoding: bytes, as: UTF8.self)
            case (4, .bytes(let bytes)):
                var sticker = ProtoReader(bytes)
                while let inner = try sticker.next() {
                    if inner.0 == 1, case .varint(let id) = inner.1, id <= UInt64(UInt32.max) {
                        manifest.stickers.append(UInt32(id))
                    }
                }
            default: break
            }
        }
        return manifest
    }

    private static func isHex(_ text: String) -> Bool {
        text.allSatisfy { $0.isHexDigit }
    }

    private static func bytes(hex: String) -> Data? {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}

/// The few bits of protobuf a sticker manifest needs: varints and
/// length-delimited fields; fixed-width fields are skipped.
private struct ProtoReader {
    enum Value { case varint(UInt64), bytes([UInt8]) }

    private let bytes: [UInt8]
    private var index = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func next() throws -> (Int, Value)? {
        guard index < bytes.count else { return nil }
        let tag = try varint()
        let field = Int(tag >> 3)
        switch tag & 7 {
        case 0: return (field, .varint(try varint()))
        case 2:
            let length = Int(try varint())
            guard length >= 0, index + length <= bytes.count else { throw SignalStickerPack.Failure.badData }
            defer { index += length }
            return (field, .bytes(Array(bytes[index..<index + length])))
        case 1: try skip(8); return try next()
        case 5: try skip(4); return try next()
        default: throw SignalStickerPack.Failure.badData
        }
    }

    private mutating func skip(_ count: Int) throws {
        guard index + count <= bytes.count else { throw SignalStickerPack.Failure.badData }
        index += count
    }

    private mutating func varint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count, shift < 64 {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw SignalStickerPack.Failure.badData
    }
}
