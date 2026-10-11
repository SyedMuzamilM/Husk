import Darwin
import Foundation

/// Identity and change metadata captured before confirmation and checked again
/// before action. Path-based Foundation Trash still has a residual race window.
struct FileIdentity: Hashable, Codable, Sendable {
    let device: Int32
    let inode: UInt64
    let birthSeconds: Int64
    let birthNanoseconds: Int64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let size: Int64
    let mode: UInt16
    let owner: UInt32

    static func read(_ path: String) throws -> FileIdentity {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO, userInfo: [NSFilePathErrorKey: path])
        }
        return FileIdentity(device: info.st_dev, inode: info.st_ino,
                            birthSeconds: Int64(info.st_birthtimespec.tv_sec),
                            birthNanoseconds: Int64(info.st_birthtimespec.tv_nsec),
                            modifiedSeconds: Int64(info.st_mtimespec.tv_sec),
                            modifiedNanoseconds: Int64(info.st_mtimespec.tv_nsec),
                            size: info.st_size, mode: info.st_mode, owner: info.st_uid)
    }

    var isSymbolicLink: Bool { mode & UInt16(S_IFMT) == UInt16(S_IFLNK) }
}
