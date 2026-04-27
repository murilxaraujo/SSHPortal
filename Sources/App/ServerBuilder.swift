import Hummingbird
import Logging

public enum ServerBuilder {
    public static func makeApp(
        config: Config,
        keyStore: KeyStore
    ) throws -> some ApplicationProtocol {
        var logger = Logger(label: "sshportal")
        logger.logLevel = Logger.Level(rawValue: config.logLevel) ?? .info

        let router = Router()
        KeyRoutes.register(router, store: keyStore)

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(config.host, port: config.port),
                serverName: "sshportal"
            ),
            logger: logger
        )
        return app
    }
}
