import Hummingbird
import Foundation

public struct HealthResponse: ResponseEncodable, Codable {
    public let status: String
    public let keys_loaded: Int
    public let last_refresh: String?
}

public enum KeyRoutes {
    public static func register(_ router: Router<some RequestContext>, store: KeyStore) {
        router.get("/health") { _, _ -> HealthResponse in
            let count = await store.count()
            let last = await store.lastRefresh
            let iso = last.map { ISO8601DateFormatter().string(from: $0) }
            return HealthResponse(status: "ok", keys_loaded: count, last_refresh: iso)
        }
    }
}
