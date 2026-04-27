import Foundation
import Hummingbird
import HTTPTypes

/// Per-IP token-bucket rate limiter.
///
/// Each IP address gets its own bucket of `perMinute` tokens that refills
/// continuously at `perMinute / 60` tokens per second. ``allow(ip:)``
/// returns `false` once the bucket is empty.
public actor TokenBucketRateLimiter {
    private struct Bucket {
        var tokens: Double
        var lastRefill: Date
    }

    public let capacity: Double
    public let refillPerSecond: Double
    private let now: @Sendable () -> Date
    private var buckets: [String: Bucket] = [:]

    public init(perMinute: Int, now: @escaping @Sendable () -> Date = Date.init) {
        self.capacity = Double(perMinute)
        self.refillPerSecond = Double(perMinute) / 60.0
        self.now = now
    }

    public func allow(ip: String) -> Bool {
        let n = now()
        var bucket = buckets[ip] ?? Bucket(tokens: capacity, lastRefill: n)
        let elapsed = n.timeIntervalSince(bucket.lastRefill)
        bucket.tokens = min(capacity, bucket.tokens + elapsed * refillPerSecond)
        bucket.lastRefill = n
        guard bucket.tokens >= 1 else {
            buckets[ip] = bucket
            return false
        }
        bucket.tokens -= 1
        buckets[ip] = bucket
        return true
    }
}

/// Hummingbird middleware that gates incoming requests through a
/// ``TokenBucketRateLimiter``, keyed by the first hop in
/// `X-Forwarded-For` (or the literal string `unknown` if absent).
public struct RateLimitMiddleware<Context: RequestContext>: RouterMiddleware {
    public let limiter: TokenBucketRateLimiter

    public init(limiter: TokenBucketRateLimiter) {
        self.limiter = limiter
    }

    public func handle(
        _ input: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let xff = input.headers[values: HTTPField.Name("X-Forwarded-For")!].first
        let ip: String
        if let raw = xff?.split(separator: ",").first.map(String.init) {
            ip = raw.trimmingCharacters(in: CharacterSet.whitespaces)
        } else {
            ip = "unknown"
        }
        if await limiter.allow(ip: ip) {
            return try await next(input, context)
        }
        var headers = HTTPFields()
        headers[.contentType] = "text/plain"
        return Response(
            status: .tooManyRequests,
            headers: headers,
            body: ResponseBody(byteBuffer: .init(string: "rate limited\n"))
        )
    }
}
