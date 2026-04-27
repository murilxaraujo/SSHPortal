import Foundation
import ServiceLifecycle
import Logging

public struct RefreshService: Service {
    public let store: KeyStore
    public let loader: KeyLoader
    public let intervalSeconds: Int
    public let logger: Logger

    public init(store: KeyStore, loader: KeyLoader, intervalSeconds: Int, logger: Logger) {
        self.store = store
        self.loader = loader
        self.intervalSeconds = intervalSeconds
        self.logger = logger
    }

    public func run() async throws {
        await store.refreshOnce(using: loader)
        let initialCount = await store.count()
        logger.info("initial keys loaded: \(initialCount)")
        guard intervalSeconds > 0 else {
            try await gracefulShutdown()
            return
        }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(intervalSeconds))
            } catch {
                break
            }
            if Task.isCancelled { break }
            await store.refreshOnce(using: loader)
            let count = await store.count()
            logger.info("keys refreshed: \(count)")
        }
    }
}
