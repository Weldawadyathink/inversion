import Foundation

extension Data {
    func getBit(_ bitIndex: Int) -> UInt8 {
        let byteIndex = bitIndex / 8
        let bitInByte = 7 - (bitIndex % 8)
        return (self[byteIndex] >> bitInByte) & 1
    }
    mutating func setBit(at bitIndex: Int, to value: UInt8) {
        let byteIndex = bitIndex / 8
        let bitInByte = 7 - (bitIndex % 8)
        if value == 1 {
            self[byteIndex] |= (1 << bitInByte)
        } else {
            self[byteIndex] &= ~(1 << bitInByte)
        }
    }
    var binaryString: String {
        self.map { String($0, radix: 2).leftPad(toLength: self.count * 8, withPad: "0") }.joined()
    }
}

extension String {
    func leftPad(toLength: Int, withPad character: Character) -> String {
        if self.count < toLength {
            return String(repeatElement(character, count: toLength - self.count)) + self
        } else {
            return self
        }
    }
}

enum HammingCheckResult {
    case valid
    case recoverableError(bitIndex: Int)
    case nonRecoverableError
}

class Hamming {
    // Used to distinguish between parity bits and data bits in the lookup table
    // Must be higher than the number of parity bits per block
    private static let parityBitOffset = 100
    private static let hammingLookupTable: [Int] = (0..<128).map { i in
        if i == 0 {
            return 0 - parityBitOffset
        } else if (i & (i - 1)) == 0 {
            // Negative numbers represent parity bits
            return i.trailingZeroBitCount + 1 - parityBitOffset
        } else {
            var parityCount = 0
            var p = 1
            while p <= i {
                parityCount += 1
                p <<= 1
            }
            return i - parityCount - 1  // -1 because the first data bit should be bit 0
        }
    }

    private var _parity: Data
    private var _data: Data
    private var _hasParityBeenSet: Bool

    private static func ensureBytes(data: Data, bytes: Int) {
        if data.count != bytes {
            fatalError("value must have \(bytes) bytes, input had \(data.count) bytes")
        }
    }

    init() {
        _data = Data(count: 15)
        _parity = Data(count: 1)
        _hasParityBeenSet = false
    }

    init(data: Data) {
        Hamming.ensureBytes(data: data, bytes: 15)
        _data = data
        _hasParityBeenSet = false
        _parity = Data(count: 1)
    }

    init(data: Data, parity: Data) {
        Hamming.ensureBytes(data: data, bytes: 15)
        Hamming.ensureBytes(data: parity, bytes: 1)
        _data = data
        _parity = parity
        _hasParityBeenSet = true
    }

    var parity: Data {
        get {
            return _parity
        }
        set {
            Hamming.ensureBytes(data: newValue, bytes: 1)
            _parity = newValue
            _hasParityBeenSet = true
        }
    }

    var data: Data {
        get {
            return _data
        }
        set {
            Hamming.ensureBytes(data: newValue, bytes: 15)
            _data = newValue
        }
    }

    var hammingData: Data {
        get {
            var output = Data(count: 16)
            for i in 0..<128 {
                let bitIndex = Hamming.hammingLookupTable[i]
                if bitIndex < 0 {
                    output.setBit(at: i, to: parity.getBit(bitIndex + Hamming.parityBitOffset))
                } else {
                    output.setBit(at: i, to: data.getBit(bitIndex))
                }
            }
            return output
        }
        set {
            Hamming.ensureBytes(data: newValue, bytes: 16)
            for i in 0..<128 {
                let bitIndex = Hamming.hammingLookupTable[i]
                if bitIndex < 0 {
                    parity.setBit(
                        at: bitIndex, to: newValue.getBit(bitIndex + Hamming.parityBitOffset))
                } else {
                    data.setBit(at: bitIndex, to: newValue.getBit(bitIndex))
                    _hasParityBeenSet = true
                }
            }
        }
    }

    func generateParity(force: Bool = false) throws {
        if force {
            _hasParityBeenSet = false
        }
        if _hasParityBeenSet {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Parity has already been set"])
        }
        let hammingData = hammingData
        for p in 0..<7 {
            let parityPosition = 1 << p
            var parityValue: UInt8 = 0
            for i in 1..<128 {
                if (i & parityPosition) != 0 {
                    parityValue ^= hammingData.getBit(i)
                }
            }
            _parity.setBit(at: p, to: parityValue)
        }
    }

    func checkParity() -> HammingCheckResult {
        // AI generated not checked
        var syndrome = 0
        var overallParity: UInt8 = 0
        for i in 1..<128 {
            let bit = data.getBit(i)
            if bit == 1 {
                syndrome ^= i
                overallParity ^= 1
            }
        }
        if overallParity != 0 {
            if syndrome == 0 {
                return .nonRecoverableError
            }
        }
        if syndrome == 0 {
            return .valid
        } else if syndrome > 0 && syndrome < 128 {
            return .recoverableError(bitIndex: syndrome)
        } else {
            return .nonRecoverableError
        }
    }
}

class HammingFile {
    private var _hammings: [Hamming]

    subscript(index: Int) -> Hamming {
        return _hammings[index]
    }

    init(filename: String) throws {
        _hammings = []
        let url = URL(fileURLWithPath: filename)
        let fileData = try Data(contentsOf: url)
        let chunkSize = 15
        var offset = 0
        while offset < fileData.count {
            let end = min(offset + chunkSize, fileData.count)
            var chunk = fileData.subdata(in: offset..<end)
            if chunk.count < chunkSize {
                // Pad end of file with zeros
                chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
            }
            let hamming = Hamming(data: chunk)
            try! hamming.generateParity()  // Only throws if parity has already been set, so will never throw
            _hammings.append(hamming)
            offset += chunkSize
        }
    }

    init(filename: String, parities: [Data]) throws {
        _hammings = []
        let url = URL(fileURLWithPath: filename)
        let fileData = try Data(contentsOf: url)
        let chunkSize = 15

        // Calculate expected number of parity blocks
        let expectedParityCount = (fileData.count + chunkSize - 1) / chunkSize

        // Check if parity array length matches expected count
        guard parities.count == expectedParityCount else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Parity array length mismatch"])
        }

        var offset = 0
        while offset < fileData.count {
            let end = min(offset + chunkSize, fileData.count)
            var chunk = fileData.subdata(in: offset..<end)
            if chunk.count < chunkSize {
                // Pad end of file with zeros
                chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
            }
            let hamming = Hamming(data: chunk, parity: parities[offset / chunkSize])
            _hammings.append(hamming)
            offset += chunkSize
        }
    }

    func checkParity() -> [HammingCheckResult] {
        return _hammings.map { $0.checkParity() }
    }

    func prettyPrint() {
        for (i, hamming) in _hammings.enumerated() {
            let dataText =
                String(data: hamming.data, encoding: .utf8)
                ?? hamming.data.map { String(format: "%02x", $0) }.joined()
            print("Block \(i): \(hamming.parity.binaryString) | \(dataText)")
        }
    }

    var parities: [Data] {
        return _hammings.map { $0.parity }
    }
}
