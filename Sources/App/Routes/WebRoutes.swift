import Hummingbird
import Foundation

/// Server-rendered HTML routes — currently just `GET /`.
public enum WebRoutes {
    public static func register(_ router: Router<some RequestContext>, store: KeyStore, config: Config) {
        router.get("/") { _, _ -> Response in
            let keys = await store.all()
            let last = await store.lastRefresh
            let html = IndexView.render(config: config, keys: keys, lastRefresh: last)
            var headers = HTTPFields()
            headers[.contentType] = "text/html; charset=utf-8"
            headers[.cacheControl] = "no-store"
            return Response(
                status: .ok,
                headers: headers,
                body: ResponseBody(byteBuffer: .init(string: html))
            )
        }
    }
}
