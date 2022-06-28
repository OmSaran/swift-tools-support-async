//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation

/// Run the given computations on a given array in batches, exercising
/// a specified amount of parallelism.
///
/// - Discussion:
///     For some blocking operations (such as file system accesses) executing
///     them on the NIO loops is very expensive since it blocks the event
///     processing machinery. Here we use extra threads for such operations.
public class LLBBatchingFutureOperationQueue {
    // OperationQueue based implementation
    private var oq: LLBBatchingFutureOperationQueueDeprecated?
    
    // DispatchQueue based implementation
    private var dq: LLBBatchingFutureDispatchQueue?
    
    public var group: LLBFuturesDispatchGroup { oq?.group ?? dq!.group }
    
    /// Maximum number of operations executed concurrently.
    public var maxOpCount: Int {
        get { oq?.maxOpCount ?? dq!.maxOpCount }
        set {
            if var q = oq {
                q.maxOpCount = newValue
                return
            }
            dq!.maxOpCount = newValue
        }
    }
    
    public var opCount: Int { oq?.opCount ?? dq!.opCount }
    
    @available(*, deprecated, message: "isSuspended is deprecated")
    public var isSuspended: Bool { oq?.isSuspended ?? dq!.isSuspended }
    
    ///
    /// - Parameters:
    ///    - name:      Unique string label, for logging.
    ///    - group:     Threads capable of running futures.
    ///    - maxConcurrentOperationCount:
    ///                 Operations to execute in parallel.
    @available(*, deprecated, message: "'qualityOfService' is deprecated: Use 'dispatchQoS'")
    public init(name: String, group: LLBFuturesDispatchGroup, maxConcurrentOperationCount maxOpCount: Int, qualityOfService: QualityOfService = .default) {
        self.oq = LLBBatchingFutureOperationQueueDeprecated(name: name, group: group, maxConcurrentOperationCount: maxOpCount, qualityOfService: qualityOfService)
        self.dq = nil
    }
    
    ///
    /// - Parameters:
    ///    - name:      Unique string label, for logging.
    ///    - group:     Threads capable of running futures.
    ///    - maxConcurrentOperationCount:
    ///                 Operations to execute in parallel.
    public init(name: String, group: LLBFuturesDispatchGroup, maxConcurrentOperationCount maxOpCount: Int, dispatchQoS: DispatchQoS) {
        self.dq = LLBBatchingFutureDispatchQueue(name: name, group: group, maxConcurrentOperationCount: maxOpCount, dispatchQoS: dispatchQoS)
        self.oq = nil
    }
    
    public func execute<T>(_ body: @escaping () throws -> T) -> LLBFuture<T> {
        return oq?.execute(body) ?? dq!.execute(body)
    }
    
    public func execute<T>(_ body: @escaping () -> LLBFuture<T>) -> LLBFuture<T> {
        return oq?.execute(body) ?? dq!.execute(body)
    }
    
    /// Order-preserving parallel execution. Wait for everything to complete.
    public func execute<A,T>(_ args: [A], minStride: Int = 1, _ body: @escaping (ArraySlice<A>) throws -> [T]) -> LLBFuture<[T]> {
        return oq?.execute(args, minStride: minStride, body) ?? dq!.execute(args, minStride: minStride, body)
    }
    
    /// Order-preserving parallel execution.
    /// Do not wait for all executions to complete, returning individual futures.
    public func executeNoWait<A,T>(_ args: [A], minStride: Int = 1, maxStride: Int = Int.max, _ body: @escaping (ArraySlice<A>) throws -> [T]) -> [LLBFuture<[T]>] {
        return oq?.executeNoWait(args, minStride: minStride, maxStride: maxStride, body) ?? dq!.executeNoWait(args, minStride: minStride, maxStride: maxStride, body)
    }
}
