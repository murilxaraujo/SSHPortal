import Hummingbird
import Logging
import ServiceLifecycle

/// Pure factory that wires a ``Config`` and a ``KeyStore`` (plus an
/// optional ``KeyLoader``) into a ready-to-run Hummingbird application.
///
/// All side effects live in ``App``; this enum is fully testable and is
/// what the test suite uses to spin up an in-memory server per case.
public enum ServerBuilder {
    public static func makeApp(
        config: Config,
        keyStore: KeyStore,
        loader: KeyLoader? = nil
    ) throws -> some ApplicationProtocol {
        var logger = Logger(label: "sshportal")
        logger.logLevel = Logger.Level(rawValue: config.logLevel) ?? .info

        let router = Router()
        let limiter = TokenBucketRateLimiter(perMinute: 60)
        router.middlewares.add(RateLimitMiddleware<BasicRequestContext>(limiter: limiter))
        KeyRoutes.register(router, store: keyStore)
        WebRoutes.register(router, store: keyStore, config: config)

        var services: [any Service] = []
        if let loader {
            services.append(RefreshService(
                store: keyStore,
                loader: loader,
                intervalSeconds: config.refreshInterval,
                logger: logger
            ))
        }

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(config.host, port: config.port),
                serverName: "sshportal"
            ),
            services: services,
            logger: logger
        )
        return app
    }
}
