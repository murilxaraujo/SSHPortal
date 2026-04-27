import Hummingbird
import AsyncHTTPClient
import Logging
import Foundation

@main
struct AppMain {
    static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        let config = Config.fromEnvironment(env: env)
        var logger = Logger(label: "sshportal")
        logger.logLevel = Logger.Level(rawValue: config.logLevel) ?? .info

        let file: KeysFile
        do {
            file = try KeysFile.load(path: config.keysFile)
        } catch {
            logger.warning("could not load \(config.keysFile): \(error). Starting with empty config.")
            file = KeysFile(title: nil, sources: .init())
        }

        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        let github = RemoteKeyFetcher(source: .github, baseURL: "https://github.com", httpClient: httpClient, logger: logger)
        let gitlab = RemoteKeyFetcher(source: .gitlab, baseURL: "https://gitlab.com", httpClient: httpClient, logger: logger)
        let loader = KeyLoader(file: file, github: github, gitlab: gitlab, logger: logger)

        let store = KeyStore.empty()
        let app = try ServerBuilder.makeApp(config: config, keyStore: store, loader: loader)
        do {
            try await app.runService()
            try await httpClient.shutdown()
        } catch {
            try? await httpClient.shutdown()
            throw error
        }
    }
}
