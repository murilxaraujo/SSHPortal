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

        router.get("/keys") { _, _ -> Response in
            let keys = await store.all()
            let body = keys.map(\.publicKey).joined(separator: "\n") + (keys.isEmpty ? "" : "\n")
            var headers = HTTPFields()
            headers[.contentType] = "text/plain; charset=utf-8"
            headers[.cacheControl] = "no-store"
            return Response(
                status: .ok,
                headers: headers,
                body: ResponseBody(byteBuffer: .init(string: body))
            )
        }
    }
}
