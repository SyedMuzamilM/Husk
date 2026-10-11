import AppKit
import Darwin
import Foundation

struct ProcessIdentity: Sendable, Hashable {
    let pid: Int32
    let uid: UInt32
    let startSeconds: UInt64
    let startMicroseconds: UInt64
    let command: String

    static func read(_ pid: Int32) throws -> ProcessIdentity {
        guard pid > 1 else { throw RemovalError.changed("Invalid or protected process.") }
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.stride
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size else {
            throw RemovalError.changed("Process exited or its identity cannot be verified.")
        }
        let command = withUnsafeBytes(of: info.pbi_name) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return ProcessIdentity(pid: pid, uid: info.pbi_uid, startSeconds: info.pbi_start_tvsec,
                               startMicroseconds: info.pbi_start_tvusec, command: command)
    }

    var canTerminate: Bool {
        uid == getuid() && pid > 1 && pid != getpid()
            && !["loginwindow", "WindowServer", "launchd", "kernel_task", "Husk", "tccd", "securityd", "cfprefsd", "runningboardd"].contains(command)
    }
}

enum ProcessControl {
    @MainActor
    static func terminate(_ identity: ProcessIdentity, force: Bool) throws {
        guard identity.canTerminate, try ProcessIdentity.read(identity.pid) == identity else {
            throw RemovalError.changed("Process changed since confirmation, is protected, or belongs to another user.")
        }
        // Use the app API when possible so Quit permits normal shutdown.
        if let app = NSRunningApplication(processIdentifier: identity.pid) {
            guard force ? app.forceTerminate() : app.terminate() else {
                throw RemovalError.changed("The application rejected the quit request.")
            }
        } else if kill(identity.pid, force ? SIGKILL : SIGTERM) != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPERM)
        }
    }
}
