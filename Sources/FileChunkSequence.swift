import Foundation

struct FileChunkIterator: IteratorProtocol {
  private let handle: FileHandle
  private let chunkSize: Int
  private let padLastChunk: Bool

  init(fileHandle: FileHandle, chunkSize: Int, padLastChunk: Bool = true) {
    self.handle = fileHandle
    self.chunkSize = chunkSize
    self.padLastChunk = padLastChunk
  }

  mutating func next() -> Data? {
    var chunk = handle.readData(ofLength: chunkSize)
    guard chunk.count > 0 else {
      return nil
    }
    if chunk.count < chunkSize && padLastChunk {
      chunk.append(
        contentsOf: [UInt8](
          repeating: 0, count: chunkSize - chunk.count))
    }
    return chunk
  }
}

struct FileChunkSequence: Sequence {
  typealias Iterator = FileChunkIterator
  typealias Element = Data

  private let fileName: String
  private let chunkSize: Int
  private let padLastChunk: Bool
  private let handle: FileHandle

  init(fileName: String, chunkSize: Int, padLastChunk: Bool = true) throws {
    self.handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: fileName))
    self.fileName = fileName
    self.chunkSize = chunkSize
    self.padLastChunk = padLastChunk
  }

  func makeIterator() -> FileChunkIterator {
    return FileChunkIterator(
      fileHandle: self.handle, chunkSize: self.chunkSize, padLastChunk: self.padLastChunk)
  }
}
