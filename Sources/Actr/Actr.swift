import ActrSwift
import Foundation
import SwiftProtobuf

/// A concurrency-safe reference to a running ACTR actor.
public actor Actr {
    private let inner: ActrRefWrapper

    /// Returns the actor id of this running actor.
    public var id: ActrId {
        inner.actorId()
    }

    /// Performs a protobuf-based RPC call.
    public func call<Req: Message, Res: Message>(
        route: String,
        message: Req,
        payloadType: PayloadType = Req.payloadType,
        timeoutMs: Int64 = 30_000
    ) async throws -> Res {
        guard !route.isEmpty else {
            throw ActrError.StateError(msg: "route must not be empty")
        }

        let requestData = try message.serializedData()
        let responseData = try await inner.call(
            routeKey: route,
            payloadType: payloadType,
            requestPayload: requestData,
            timeoutMs: timeoutMs
        )
        return try Res(serializedBytes: responseData)
    }

    /// Discovers actors of the given type.
    public func discover(type: ActrType, limit: Int = 1) async throws -> [ActrId] {
        guard limit > 0 else { return [] }
        guard limit <= Int(UInt32.max) else {
            throw ActrError.StateError(msg: "limit is too large")
        }
        return try await inner.discover(targetType: type, count: UInt32(limit))
    }

    /// Shuts down the actor and waits for it to terminate.
    public func stop() async {
        inner.shutdown()
        await inner.waitForShutdown()
    }

    internal init(inner: ActrRefWrapper) {
        self.inner = inner
    }
}
