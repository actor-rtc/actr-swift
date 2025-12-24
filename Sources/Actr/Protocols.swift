import ActrSwift
import Foundation
import SwiftProtobuf

/// Context for RPC and streaming messages.
public protocol Context: Sendable {
    var actrId: ActrId { get }
}

/// Envelope used by dispatchers to route and decode RPC messages.
public struct RpcEnvelope: Sendable {
    public let routeKey: String
    public let payload: Data

    public init(routeKey: String, payload: Data) {
        self.routeKey = routeKey
        self.payload = payload
    }
}

/// Associates an RPC request message with its response type and routing metadata.
public protocol RpcRequest: Message, Sendable {
    associatedtype Response: Message

    static var routeKey: String { get }
}
