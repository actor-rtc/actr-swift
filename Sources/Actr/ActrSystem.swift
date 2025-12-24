import ActrSwift
import Foundation

/// A high-level entry point for creating an ACTR system and spawning nodes.
public final class ActrSystem: Sendable {
    private let inner: ActrSystemWrapper

    /// Creates a system from a TOML config file path.
    public static func from(tomlConfig path: String) async throws -> ActrSystem {
        let wrapper = try await ActrSystemWrapper.newFromFile(configPath: path)
        return ActrSystem(inner: wrapper)
    }

    /// Creates a system from a TOML config file URL.
    public static func from(tomlConfig url: URL) async throws -> ActrSystem {
        guard url.isFileURL else {
            throw ActrError.ConfigError(msg: "tomlConfig URL must be a file URL")
        }
        return try await from(tomlConfig: url.path)
    }

    /// Attaches a workload and returns a node that can be started.
    public func spawn(workload: Workload) throws -> ActrNode {
        let nodeWrapper = try inner.attach(callback: workload)
        return ActrNode(inner: nodeWrapper)
    }

    init(inner: ActrSystemWrapper) {
        self.inner = inner
    }
}
