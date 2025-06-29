import CryptoKit
import Foundation

extension Data {
  var sha256: String {
    SHA256.hash(data: self)
      .compactMap { String(format: "%02x", $0) }
      .joined()
  }
}

class HammingFileProvider {
  static let chunkSize = 15
  private var _hammings: [Hamming]
  private var external_filename: String
  private var internal_filename: String
  private var size: Int
  private var hash: String

  subscript(index: Int) -> Hamming {
    return _hammings[index]
  }

  init(external_filename: String) throws {
    // Previously unknown file
    // Generate parities and save to database

    let fileData = try Data(contentsOf: URL(fileURLWithPath: external_filename))

    // try Database.pool.write { db in
    //     let row = try db.read(
    //         sql: """
    //             SELECT id, hash, size, internal_filename, external_filename
    //             FROM files
    //             WHERE external_filename = ?
    //             """,
    //         arguments: [external_filename]
    //     )
    //     if row.count > 0 {
    //         print("File already exists in database")
    //         if row[0].size != size {
    //             print("File size mismatch")
    //             fatalError("File size mismatch")
    //         }
    //         if row[0].hash != hash {
    //             print("File hash mismatch")
    //             fatalError("File hash mismatch")
    //         }
    //         self.internal_filename = row[0].internal_filename
    //         self.external_filename = row[0].external_filename
    //     } else {
    //         print("File does not exist in database")
    //         try db.execute(
    //             sql:
    //                 "INSERT INTO files (external_filename, internal_filename, size, hash) VALUES (?, ?, ?, ?)",
    //             arguments: [external_filename, internal_filename, size, hash]
    //         )
    //     }
    // }

    self._hammings = []
    self.external_filename = external_filename
    self.internal_filename = UUID().uuidString
    var offset = 0
    while offset < fileData.count {
      let end = min(offset + HammingFileProvider.chunkSize, fileData.count)
      var chunk = fileData.subdata(in: offset..<end)
      if chunk.count < HammingFileProvider.chunkSize {
        // Pad end of file with zeros
        chunk.append(
          contentsOf: [UInt8](
            repeating: 0, count: HammingFileProvider.chunkSize - chunk.count))
      }
      let hamming = Hamming(data: chunk)
      try! hamming.generateParity()  // Only throws if parity has already been set, so will never throw
      _hammings.append(hamming)
      offset += HammingFileProvider.chunkSize
    }
    self.size = fileData.count
    self.hash = fileData.sha256
  }

  // init(filename: String, parities: [Data]) throws {
  //     _hammings = []
  //     self.filename = filename
  //     let url = URL(fileURLWithPath: filename)
  //     let fileData = try Data(contentsOf: url)
  //     let chunkSize = 15

  //     // Calculate expected number of parity blocks
  //     let expectedParityCount = (fileData.count + chunkSize - 1) / chunkSize

  //     // Check if parity array length matches expected count
  //     guard parities.count == expectedParityCount else {
  //         throw NSError(
  //             domain: "HammingParityError", code: 1,
  //             userInfo: [NSLocalizedDescriptionKey: "Parity array length mismatch"])
  //     }

  //     var offset = 0
  //     while offset < fileData.count {
  //         let end = min(offset + chunkSize, fileData.count)
  //         var chunk = fileData.subdata(in: offset..<end)
  //         if chunk.count < chunkSize {
  //             // Pad end of file with zeros
  //             chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
  //         }
  //         let hamming = Hamming(data: chunk, parity: parities[offset / chunkSize])
  //         _hammings.append(hamming)
  //         offset += chunkSize
  //     }
  // }

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
        print(
          "Attempting repair of block \(i) at bit \(bitIndex) in file: \(external_filename)"
        )
        dataErrors += 1
      case .recoverableErrorInParity(let bitIndex):
        print(
          "Attempting repair of block \(i) at bit \(bitIndex) in file: \(external_filename)"
        )
        parityErrors += 1
      case .nonRecoverableError:
        unrecoverableErrors += 1
      }
    }
    if dataErrors + parityErrors + unrecoverableErrors > 0 {
      print(
        "Found errors in file: \(external_filename), \(dataErrors) data, \(parityErrors) parity, \(unrecoverableErrors) unrecoverable"
      )
    } else {
      print("No errors found in file: \(external_filename)")
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
