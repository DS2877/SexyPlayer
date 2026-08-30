import Foundation

public extension Array where Element: Sendable {
    /// `map`, but the work is split into chunks and run across all CPU cores.
    /// Output order matches input. For pure, CPU-bound transforms over large
    /// arrays (catalog normalization) this is a 4–6× win on an Apple TV.
    func concurrentMap<T: Sendable>(
        minimumBatch: Int = 400,
        _ transform: @escaping @Sendable (Element) -> T
    ) async -> [T] {
        guard count > minimumBatch else { return map(transform) }

        let cores = Swift.max(2, ProcessInfo.processInfo.activeProcessorCount)
        let batchSize = Swift.max(minimumBatch, (count + cores - 1) / cores)
        let input = self

        return await withTaskGroup(of: (Int, [T]).self) { group in
            var start = 0
            var batchIndex = 0
            while start < input.count {
                let end = Swift.min(start + batchSize, input.count)
                let slice = Array(input[start ..< end])
                let idx = batchIndex
                group.addTask { (idx, slice.map(transform)) }
                start = end
                batchIndex += 1
            }

            var results = [[T]](repeating: [], count: batchIndex)
            for await (idx, batch) in group { results[idx] = batch }
            return results.flatMap { $0 }
        }
    }
}
