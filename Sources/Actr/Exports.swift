import ActrSwift

/// Re-export commonly used low-level types so applications can `import Actr`
/// without also importing `ActrSwift`.
public typealias ActrError = ActrSwift.ActrError
public typealias ActrId = ActrSwift.ActrId
public typealias ActrType = ActrSwift.ActrType
public typealias PayloadType = ActrSwift.PayloadType
public typealias Realm = ActrSwift.Realm
public typealias ContextBridge = ActrSwift.ContextBridge
public typealias Workload = ActrSwift.WorkloadBridge
public typealias DataStream = ActrSwift.DataStream
public typealias MetadataEntry = ActrSwift.MetadataEntry
