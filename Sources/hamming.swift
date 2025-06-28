import Foundation

extension Data {
    func bit(at bitIndex: Int) -> UInt8 {
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

public enum HammingCheckResult {
    case valid
    case recoverableError(bitIndex: Int)
    case nonRecoverableError
}

public struct Hamming {
    public static func buildParityDataBlock(data: Data, parity: Data) throws -> Data {
        // Constructs a data block that contains the hamming parity bits and the data bits
        // SECDED (128,120)
        guard data.count == 15 else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Data must be 120 bits"])
        }
        guard parity.count == 1 else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Parity must be 8 bits"])
        }
        var output = Data(count: 16)
        var nextDataBitToRead = 0
        for i in 0..<128 {
            if i == 0 {
                output.setBit(at: i, to: parity.bit(at: 0))
            } else if (i & (i - 1)) == 0 {
                output.setBit(at: i, to: parity.bit(at: i.trailingZeroBitCount + 1))
            } else {
                output.setBit(at: i, to: data.bit(at: nextDataBitToRead))
                nextDataBitToRead += 1
            }
        }
        return output
    }

    public static func generateParityBits(_ input: Data) throws -> Data {
        // Generates the hamming parity bits for a data block
        // SECDED (120,128)
        // Returns a single byte. Overall parity is bit 0
        guard input.count == 15 else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Input must be 120 bits"])
        }
        var bits = try buildParityDataBlock(data: input, parity: Data(count: 1))
        // Set the 7 Hamming parity bits
        for p in 0..<7 {
            let parityPosition = 1 << p
            var parityValue: UInt8 = 0
            for i in 1..<128 {
                if (i & parityPosition) != 0 {
                    parityValue ^= bits.bit(at: i)
                }
            }
            bits.setBit(at: parityPosition, to: parityValue)
        }
        // Set the overall parity bit (bit 0)
        var overallParity: UInt8 = 0
        for i in 1..<128 {
            overallParity ^= bits.bit(at: i)
        }
        bits.setBit(at: 0, to: overallParity)
        return bits
    }

    public static func calculateFileParity(from filename: String) throws -> [(
        parityBits: Data, dataBits: Data
    )] {
        // Calculates the hamming parity bits for a file
        // SECDED (120,128)
        // Returns an array of tuples, each containing the parity bits and data bits for a block
        let url = URL(fileURLWithPath: filename)
        let fileData = try Data(contentsOf: url)
        let chunkSize = 15
        var blocks: [(parityBits: Data, dataBits: Data)] = []
        var offset = 0
        while offset < fileData.count {
            let end = min(offset + chunkSize, fileData.count)
            var chunk = fileData.subdata(in: offset..<end)
            if chunk.count < chunkSize {
                chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
            }
            let parity = try generateParityBits(chunk)
            let (parityBits, dataBits) = try extractParityBits(parity)
            blocks.append((parityBits, dataBits))
            offset += chunkSize
        }
        return blocks
    }

    public static func extractParityBits(_ input: Data) throws -> (parityBits: Data, dataBits: Data)
    {
        // Separates the parity bits and data bits from a data block
        // SECDED (128,120)
        // Returns a tuple containing the parity bits and data bits
        guard input.count == 16 else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Block must be 16 bits"])
        }
        var parityBits: Data = Data(count: 1)
        var dataBits: Data = Data(count: 15)
        var dataBitToSetNext = 0
        for i in 0..<128 {
            if i == 0 {
                parityBits.setBit(at: 0, to: input.bit(at: 0))
            } else if (i & (i - 1)) == 0 {
                parityBits.setBit(
                    at: i.trailingZeroBitCount + 1, to: input.bit(at: i.trailingZeroBitCount + 1))
            } else {
                dataBits.setBit(at: dataBitToSetNext, to: input.bit(at: i))
                dataBitToSetNext += 1
            }
        }
        return (parityBits, dataBits)
    }

    public static func checkParityBlock(_ block: Data) throws -> HammingCheckResult {
        // Checks the hamming parity bits for a complete data block
        // SECDED (128,120)
        // Returns a HammingCheckResult indicating the parity status of the block
        guard block.count == 16 else {
            throw NSError(
                domain: "HammingParityError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Block must be 16 bytes (128 bits)"])
        }
        var syndrome = 0
        // Calculate syndrome by checking each parity bit
        for p in 0..<7 {
            let parityPosition = 1 << p
            var parityValue: UInt8 = 0
            for i in 1..<128 {
                if (i & parityPosition) != 0 {
                    parityValue ^= block.bit(at: i)
                }
            }
            // Compare with the stored parity bit
            let storedParity = block.bit(at: parityPosition)
            if parityValue != storedParity {
                syndrome |= parityPosition
            }
        }
        // Also check the overall parity bit (bit 0)
        var overallParity: UInt8 = 0
        for i in 1..<128 {
            overallParity ^= block.bit(at: i)
        }
        let storedOverallParity = block.bit(at: 0)
        if overallParity != storedOverallParity {
            // If syndrome is zero but overall parity is wrong, it's a double-bit error (non-recoverable)
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
