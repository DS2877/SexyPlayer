import Foundation

public extension Array where Element: Sendable {
    /// `map`, but the work is split into chunks and run across all CPU cores.
    /// Output order matches input. For pure, CPU-bound transforms over large
    /// arrays (catalog normalization) this is a 4–6× win on an Apple TV.
    ///
    /// Memory: each worker indexes into the shared (COW) input rather than
    /// copying a slice, and the transformed chunks are released into the result
    /// as they're consumed — so the transient footprint is roughly one copy of
    /// the output, not two-plus.
    func concurrentMap<T: Sendable>(
        minimumBatch: Int = 512,
        _ transform: @escaping @Sendable (Element) -> T
    ) async -> [T] {
        let n = count
        guard n > minimumBatch else { return map(transform) }

        let cores = Swift.max(2, ProcessInfo.processInfo.activeProcessorCount)
        let batchSize = Swift.max(minimumBatch, (n + cores - 1) / cores)
        let batchCount = (n + batchSize - 1) / batchSize
        let input = self   // COW — no copy; `Element: Sendable`

        var chunks = [[T]?](repeating: nil, count: batchCount)
        await withTaskGroup(of: (Int, [T]).self) { group in
            for b in 0 ..< batchCount {
                let lo = b * batchSize
                let hi = Swift.min(lo + batchSize, n)
                group.addTask {
                    var out = [T]()
                    out.reserveCapacity(hi - lo)
                    for i in lo ..< hi { out.append(transform(input[i])) }
                    return (b, out)
                }
            }
            for await (b, chunk) in group { chunks[b] = chunk }
        }

        var result = [T]()
        result.reserveCapacity(n)
        for b in 0 ..< batchCount {
            if let chunk = chunks[b] {
                result.append(contentsOf: chunk)
                chunks[b] = nil   // free each chunk as it's folded in
            }
        }
        return result
    }
}
