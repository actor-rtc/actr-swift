import ActrSwift

/// A configured node that can be started to obtain a running actor reference.
public final class ActrNode: Sendable {
    private let inner: ActrNodeWrapper

    /// Starts the node and returns a high-level actor reference.
    public func start() async throws -> Actr {
        let refWrapper = try await inner.start()
        return Actr(inner: refWrapper)
    }

    internal init(inner: ActrNodeWrapper) {
        self.inner = inner
    }
}

