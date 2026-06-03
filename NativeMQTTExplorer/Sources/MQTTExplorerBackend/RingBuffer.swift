import Foundation

/// Protocol for items that express their size via a length property.
public protocol MemoryConsumptionExpressedByLength {
    var length: Int { get }
}

/// A ring buffer with capacity limits (item count + total byte size).
/// Mirroring the TS RingBuffer<T extends MemoryConsumptionExpressedByLength>.
public final class RingBuffer<T: MemoryConsumptionExpressedByLength>: @unchecked Sendable {
    public var capacity: Int        // max total bytes
    public var maxItems: Int        // max item count
    public var compactionFactor: Int

    private var items: [T?] = []
    private var start: Int = 0
    private var end: Int = 0
    private var usage: Int = 0
    private let lock = NSLock()

    public init(capacity: Int, maxItems: Int = .max, compactionFactor: Int = 10) {
        self.capacity = capacity
        self.maxItems = maxItems
        self.compactionFactor = compactionFactor
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return end - start
    }

    public var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return usage == 0
    }

    public func freeSpace() -> Int {
        lock.lock(); defer { lock.unlock() }
        return capacity - usage
    }

    public func add(_ item: T) {
        lock.lock()
        let size = item.length
        enforceCapacityConstraints(addedItemSize: size)
        usage += size
        if end >= items.count {
            items.append(item)
        } else {
            items[end] = item
        }
        end += 1

        if end > 10 * maxItems {
            compact()
        }
        lock.unlock()
    }

    public func last() -> T? {
        lock.lock(); defer { lock.unlock() }
        guard end > start else { return nil }
        return items[end - 1]
    }

    public func toArray() -> [T] {
        lock.lock(); defer { lock.unlock() }
        return Array(items[start..<end].compactMap { $0 })
    }

    public func setCapacity(items maxI: Int, bytes: Int) {
        lock.lock(); defer { lock.unlock() }
        maxItems = maxI
        capacity = bytes
    }

    public func clone() -> RingBuffer<T> {
        lock.lock()
        let copy = RingBuffer<T>(capacity: capacity, maxItems: maxItems, compactionFactor: compactionFactor)
        let snapshot = items[start..<end].compactMap { $0 }
        copy.items = snapshot
        copy.start = 0
        copy.end = snapshot.count
        copy.usage = usage
        lock.unlock()
        return copy
    }

    // MARK: - Private

    private func enforceCapacityConstraints(addedItemSize: Int) {
        let remaining = capacity - (usage + addedItemSize)
        if remaining < 0 {
            freeSomeSpace(requiredSpace: abs(remaining))
        }
        while end - start >= maxItems {
            dropFirst()
        }
    }

    private func freeSomeSpace(requiredSpace: Int) {
        while freeSpace() < requiredSpace && !isEmpty {
            dropFirst()
        }
    }

    private func dropFirst() {
        guard start < end else { return }
        let firstItem = items[start]
        items[start] = nil
        start += 1
        if let firstItem {
            usage -= firstItem.length
        }
    }

    private func compact() {
        let snapshot = items[start..<end].compactMap { $0 }
        items = snapshot
        start = 0
        end = snapshot.count
    }
}

// MARK: - Message MemoryConsumptionExpressedByLength conformance
extension Message: MemoryConsumptionExpressedByLength {}
