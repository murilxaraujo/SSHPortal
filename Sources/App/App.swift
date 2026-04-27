import Hummingbird
import Foundation

@main
struct AppMain {
    static func main() async throws {
        let config = Config.testDefault
        let store = KeyStore.empty()
        let app = try ServerBuilder.makeApp(config: config, keyStore: store)
        try await app.runService()
    }
}
