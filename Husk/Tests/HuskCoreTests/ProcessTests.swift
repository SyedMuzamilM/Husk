import Darwin
import Foundation
import Testing
@testable import HuskCore

@Suite(.serialized)
struct ProcessTests {
    @Test func drainsOutputLargerThanPipeCapacity() async throws {
        let result = try await ProcessRunner.run("/bin/dd", arguments: ["if=/dev/zero", "bs=1024", "count=300"], timeout: 3)
        #expect(result.output.count == 307_200)
        #expect(!result.errorOutput.isEmpty)
        #expect(result.exitCode == 0)
        #expect(!result.timedOut)
    }

    @Test func timeoutAndOutputLimitStopChild() async throws {
        let timeout = try await ProcessRunner.run("/bin/sleep", arguments: ["5"], timeout: 0.1)
        #expect(timeout.timedOut)
        let bounded = try await ProcessRunner.run("/usr/bin/yes", arguments: [], outputLimit: 32_768)
        #expect(bounded.truncated)
        #expect(bounded.output.count == 32_768)
    }

    @Test func cancellationStopsChild() async throws {
        let task = Task { try await ProcessRunner.run("/bin/sleep", arguments: ["10"]) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled command returned success") }
        catch is CancellationError { }
    }

    @Test func rejectsSelfAndNonpositivePIDs() throws {
        #expect(throws: (any Error).self) { try ProcessIdentity.read(0) }
        #expect(throws: (any Error).self) { try ProcessIdentity.read(-1) }
        #expect(try ProcessIdentity.read(getpid()).canTerminate == false)
    }

    @Test @MainActor func samplerDoesNotRetainViewModel() async throws {
        var model: StatusViewModel? = StatusViewModel()
        weak var reference = model
        model?.start()
        model = nil
        try await Task.sleep(for: .milliseconds(300))
        #expect(reference == nil)
        reference = nil
    }

    @Test func repeatedCommandsDoNotLeakFileDescriptors() async throws {
        func fdBytes() -> Int32 { proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0) }
        _ = try await ProcessRunner.run("/usr/bin/true", arguments: [])
        let before = fdBytes()
        for _ in 0..<30 { _ = try await ProcessRunner.run("/usr/bin/true", arguments: []) }
        #expect(fdBytes() <= before)
    }

    @Test func repeatedSamplingDoesNotGrowHostRights() async throws {
        func refs() -> mach_port_urefs_t {
            let host = mach_host_self()
            defer { mach_port_deallocate(mach_task_self_, host) }
            var refs: mach_port_urefs_t = 0
            mach_port_get_refs(mach_task_self_, host, MACH_PORT_RIGHT_SEND, &refs)
            return refs
        }
        let before = refs()
        let service = SystemMetricsService()
        for _ in 0..<10 {
            let (snapshot, processes) = try await service.sample()
            #expect(snapshot.processCount == processes.count)
            #expect(!processes.isEmpty)
        }
        #expect(refs() == before)
    }
}
