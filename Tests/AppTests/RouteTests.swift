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

    @Test func keysFilteredByTypeReturnsSubset() async throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA a", source: .manual)
        let b = try SSHKey.parse("ssh-rsa BBBB b", source: .manual)
        let store = KeyStore(initialKeys: [a, b])
        let app = try ServerBuilder.makeApp(config: .testDefault, keyStore: store)
        try await app.test(.router) { client in
            try await client.execute(uri: "/keys/ed25519", method: .get) { response in
                #expect(response.status == .ok)
                let body = String(buffer: response.body)
                #expect(body == "ssh-ed25519 AAAA a\n")
            }
        }
    }

    @Test func unknownKeyTypeReturns404() async throws {
        let store = KeyStore.empty()
        let app = try ServerBuilder.makeApp(config: .testDefault, keyStore: store)
        try await app.test(.router) { client in
            try await client.execute(uri: "/keys/banana", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test func keysEndpointReturnsPlainText() async throws {
        let key = SSHKey(
            type: .ed25519,
            publicKey: "ssh-ed25519 AAAA test@example",
            comment: "test",
            source: .manual,
            fingerprint: "SHA256:abc"
        )
        let store = KeyStore(initialKeys: [key])
        let app = try ServerBuilder.makeApp(config: .testDefault, keyStore: store)
        try await app.test(.router) { client in
            try await client.execute(uri: "/keys", method: .get) { response in
                #expect(response.status == .ok)
                let ct = response.headers[.contentType] ?? ""
                #expect(ct.hasPrefix("text/plain"))
                let body = String(buffer: response.body)
                #expect(body == "ssh-ed25519 AAAA test@example\n")
            }
        }
    }
}
