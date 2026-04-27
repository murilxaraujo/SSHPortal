import Hummingbird
import HummingbirdTesting
import Testing
@testable import App

@Suite struct RouteTests {
    @Test func healthEndpointReturnsOK() async throws {
        let app = try ServerBuilder.makeApp(config: .testDefault, keyStore: KeyStore.empty())
        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                #expect(response.status == .ok)
                let body = String(buffer: response.body)
                #expect(body.contains("\"status\":\"ok\""))
            }
        }
    }
}
