import Hummingbird
import Logging
import ServiceLifecycle

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
