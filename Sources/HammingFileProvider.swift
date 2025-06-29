import Foundation

class HammingFileProvider {
    private var _hammings: [Hamming]
    private var filename: String

    subscript(index: Int) -> Hamming {
        return _hammings[index]
    }

    init(filename: String) throws {
        _hammings = []
        self.filename = filename
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
        self.filename = filename
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

    func checkParity(repair: Bool = false) -> (
        dataErrors: Int, parityErrors: Int, unrecoverableErrors: Int, raw: [HammingCheckResult]
    ) {
        var dataErrors = 0
        var parityErrors = 0
        var unrecoverableErrors = 0
        var raw: [HammingCheckResult] = []
        for (i, ham) in _hammings.enumerated() {
            let result = ham.checkParity()
            raw.append(result)
            switch result {
            case .valid:
                continue
            case .recoverableErrorInData(let bitIndex):
                print("Attempting repair of block \(i) at bit \(bitIndex) in file: \(filename)")
                dataErrors += 1
            case .recoverableErrorInParity(let bitIndex):
                print("Attempting repair of block \(i) at bit \(bitIndex) in file: \(filename)")
                parityErrors += 1
            case .nonRecoverableError:
                unrecoverableErrors += 1
            }
        }
        if dataErrors + parityErrors + unrecoverableErrors > 0 {
            print(
                "Found errors in file: \(filename), \(dataErrors) data, \(parityErrors) parity, \(unrecoverableErrors) unrecoverable"
            )
        } else {
            print("No errors found in file: \(filename)")
        }
        return (dataErrors, parityErrors, unrecoverableErrors, raw)
    }

    func prettyPrint() {
        for (i, hamming) in _hammings.enumerated() {
            let parity = hamming.checkParity()
            var parityString = ""
            switch parity {
            case .nonRecoverableError:
                parityString = "ERROR"
            case .recoverableErrorInData(let bitIndex):
                parityString = "D:\(String(bitIndex).leftPad(toLength: 3, withPad: "0"))"
            case .recoverableErrorInParity(let bitIndex):
                parityString = "P:\(String(bitIndex).leftPad(toLength: 3, withPad: "0"))"
            case .valid:
                parityString = "VALID"
            }
            let dataText =
                String(data: hamming.data, encoding: .utf8)
                ?? hamming.data.map { String(format: "%02x", $0) }.joined()
            print("Block \(i): \(hamming.parity.binaryString) | \(parityString) | \(dataText)")
        }
    }

    var parities: [Data] {
        return _hammings.map { $0.parity }
    }
}
