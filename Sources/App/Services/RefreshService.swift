import Foundation
import ServiceLifecycle
import Logging

/// Background service that periodically reloads keys into ``KeyStore``.
///
/// Runs an initial load on startup, then sleeps for `intervalSeconds`
/// between refreshes. Responds to ServiceLifecycle's graceful shutdown
/// signal via `withGracefulShutdownHandler`, so SIGINT/SIGTERM ends the
/// loop cleanly.
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

        let workTask = Task { [store, loader, intervalSeconds, logger] in
            guard intervalSeconds > 0 else {
                try? await Task.sleep(for: .seconds(60 * 60 * 24 * 365))
                return
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(intervalSeconds))
                } catch {
                    return
                }
                if Task.isCancelled { return }
                await store.refreshOnce(using: loader)
                let count = await store.count()
                logger.info("keys refreshed: \(count)")
            }
        }

        await withGracefulShutdownHandler {
            await workTask.value
        } onGracefulShutdown: {
            workTask.cancel()
        }
    }
}
