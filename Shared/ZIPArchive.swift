import Foundation
import zlib

enum EPUBError: LocalizedError {
    case invalidArchive
    case invalidBook(String)
    case unsupportedCompression
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidArchive: "Tệp EPUB không phải kho ZIP hợp lệ."
        case .invalidBook(let detail): "Không đọc được EPUB: \(detail)"
        case .unsupportedCompression: "EPUB dùng phương thức nén hoặc mã hóa chưa được hỗ trợ."
        case .fileTooLarge: "EPUB quá lớn để xem nhanh."
        }
    }
}

struct ZIPArchive {
    private struct Entry {
        let localOffset: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let method: UInt16
        let flags: UInt16
    }

    private let bytes: Data
    private let entries: [String: Entry]

    init(url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 250_000_000 else { throw EPUBError.fileTooLarge }
        bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count >= 22 else { throw EPUBError.invalidArchive }

        let searchStart = max(0, bytes.count - 65_557)
        var endOffset: Int?
        for offset in stride(from: bytes.count - 22, through: searchStart, by: -1) {
            if bytes.u32(offset) == 0x06054b50,
               let commentLength = bytes.u16(offset + 20),
               offset + 22 + Int(commentLength) == bytes.count {
                endOffset = offset
                break
            }
        }
        guard let endOffset,
              let count = bytes.u16(endOffset + 10),
              let directorySize = bytes.u32(endOffset + 12),
              let directoryOffset = bytes.u32(endOffset + 16),
              count <= 20_000,
              Int(directoryOffset) <= bytes.count,
              Int(directorySize) <= bytes.count - Int(directoryOffset) else {
            throw EPUBError.invalidArchive
        }

        var parsed: [String: Entry] = [:]
        var cursor = Int(directoryOffset)
        for _ in 0..<count {
            guard bytes.u32(cursor) == 0x02014b50,
                  let flags = bytes.u16(cursor + 8),
                  let method = bytes.u16(cursor + 10),
                  let compressed = bytes.u32(cursor + 20),
                  let uncompressed = bytes.u32(cursor + 24),
                  let nameLength = bytes.u16(cursor + 28),
                  let extraLength = bytes.u16(cursor + 30),
                  let commentLength = bytes.u16(cursor + 32),
                  let localOffset = bytes.u32(cursor + 42) else {
                throw EPUBError.invalidArchive
            }
            let nameStart = cursor + 46
            let next = nameStart + Int(nameLength) + Int(extraLength) + Int(commentLength)
            guard next <= bytes.count else { throw EPUBError.invalidArchive }
            let nameData = bytes.subdata(in: nameStart..<(nameStart + Int(nameLength)))
            let name = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
            if let name, !name.hasPrefix("/"), !name.split(separator: "/").contains("..") {
                parsed[name] = Entry(localOffset: Int(localOffset),
                                     compressedSize: Int(compressed),
                                     uncompressedSize: Int(uncompressed),
                                     method: method, flags: flags)
            }
            cursor = next
        }
        entries = parsed
    }

    func data(at path: String, limit: Int = 8_000_000) throws -> Data? {
        guard let entry = entries[path] else { return nil }
        guard entry.uncompressedSize <= limit else { throw EPUBError.fileTooLarge }
        guard entry.flags & 1 == 0 else { throw EPUBError.unsupportedCompression }
        let offset = entry.localOffset
        guard bytes.u32(offset) == 0x04034b50,
              let nameLength = bytes.u16(offset + 26),
              let extraLength = bytes.u16(offset + 28) else {
            throw EPUBError.invalidArchive
        }
        let start = offset + 30 + Int(nameLength) + Int(extraLength)
        guard start <= bytes.count,
              entry.compressedSize <= bytes.count - start else {
            throw EPUBError.invalidArchive
        }
        let compressed = bytes.subdata(in: start..<(start + entry.compressedSize))
        switch entry.method {
        case 0:
            guard compressed.count == entry.uncompressedSize else { throw EPUBError.invalidArchive }
            return compressed
        case 8:
            return try inflateRaw(compressed, expectedSize: entry.uncompressedSize)
        default:
            throw EPUBError.unsupportedCompression
        }
    }

    private func inflateRaw(_ input: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        var output = Data(count: expectedSize)
        var stream = z_stream()
        let initialized = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION,
                                        Int32(MemoryLayout<z_stream>.size))
        guard initialized == Z_OK else { throw EPUBError.invalidArchive }
        defer { inflateEnd(&stream) }
        let result = input.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer(
                    mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expectedSize)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END, stream.total_out == expectedSize else {
            throw EPUBError.invalidArchive
        }
        return output
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func u32(_ offset: Int) -> UInt32? {
        guard let low = u16(offset), let high = u16(offset + 2) else { return nil }
        return UInt32(low) | UInt32(high) << 16
    }
}
