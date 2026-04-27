import Hummingbird
import Foundation

/// JSON body of `GET /health`. Stable contract — orchestrators rely on
/// `status == "ok"` for liveness.
public struct HealthResponse: ResponseEncodable, Codable {
    public let status: String
    public let keys_loaded: Int
    public let last_refresh: String?
}

/// Plain-text key endpoints plus `/health`.
///
/// Routes are registered onto an existing `Router` via ``register(_:store:)``
/// so that callers control middleware order.
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
            return plainTextResponse(keys: keys)
        }

        router.get("/keys/:type") { request, context -> Response in
            let raw = context.parameters.get("type") ?? ""
            guard let type = SSHKeyType(rawValue: raw) else {
                var headers = HTTPFields()
                headers[.contentType] = "text/plain; charset=utf-8"
                return Response(
                    status: .notFound,
                    headers: headers,
                    body: ResponseBody(byteBuffer: .init(string: "unknown key type\n"))
                )
            }
            let keys = await store.filtered(by: type)
            return plainTextResponse(keys: keys)
        }
    }

    static func plainTextResponse(keys: [SSHKey]) -> Response {
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
