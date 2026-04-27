import Testing
import Foundation
@testable import App

@Suite struct RateLimiterTests {
    @Test func allowsUnderLimit() async {
        let rl = TokenBucketRateLimiter(perMinute: 5, now: { Date(timeIntervalSince1970: 0) })
        for _ in 0..<5 {
            #expect(await rl.allow(ip: "1.2.3.4"))
        }
    }

    @Test func blocksOverLimit() async {
        let rl = TokenBucketRateLimiter(perMinute: 2, now: { Date(timeIntervalSince1970: 0) })
        _ = await rl.allow(ip: "1.2.3.4")
        _ = await rl.allow(ip: "1.2.3.4")
        let third = await rl.allow(ip: "1.2.3.4")
        #expect(third == false)
    }

    @Test func differentIpsHaveSeparateBuckets() async {
        let rl = TokenBucketRateLimiter(perMinute: 1, now: { Date(timeIntervalSince1970: 0) })
        #expect(await rl.allow(ip: "1.1.1.1"))
        #expect(await rl.allow(ip: "2.2.2.2"))
    }

    @Test func bucketRefillsOverTime() async {
        let timeBox = TimeBox()
        let rl = TokenBucketRateLimiter(perMinute: 1, now: { timeBox.now })
        #expect(await rl.allow(ip: "x"))
        #expect(await rl.allow(ip: "x") == false)
        timeBox.advance(60)
        #expect(await rl.allow(ip: "x"))
    }
}

final class TimeBox: @unchecked Sendable {
    private var current: Date = Date(timeIntervalSince1970: 0)
    private let lock = NSLock()
    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }
    func advance(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}
