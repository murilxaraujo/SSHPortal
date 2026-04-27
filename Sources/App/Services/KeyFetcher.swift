import Foundation
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import Logging

public protocol KeyFetcher: Sendable {
    func fetch(username: String) async throws -> [SSHKey]
}

public struct RemoteKeyFetcher: KeyFetcher {
    public let source: KeySource
    public let baseURL: String
    public let httpClient: HTTPClient
    public let logger: Logger
    public let timeoutSeconds: Int64

    public init(
        source: KeySource,
        baseURL: String,
        httpClient: HTTPClient,
        logger: Logger,
        timeoutSeconds: Int64 = 10
    ) {
        self.source = source
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.logger = logger
        self.timeoutSeconds = timeoutSeconds
    }

    public func fetch(username: String) async throws -> [SSHKey] {
        let url = "\(baseURL)/\(username).keys"
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "User-Agent", value: "sshportal/1.0")
        let response = try await httpClient.execute(request, timeout: .seconds(timeoutSeconds))
        guard response.status == .ok else {
            throw RemoteKeyFetcherError.httpStatus(Int(response.status.code))
        }
        let buffer = try await response.body.collect(upTo: 1024 * 64)
        let body = String(buffer: buffer)
        return Self.parseBody(body, source: source, logger: logger)
    }

    static func parseBody(_ body: String, source: KeySource, logger: Logger) -> [SSHKey] {
        body.split(whereSeparator: \.isNewline).compactMap { line in
            let s = String(line).trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return nil }
            do {
                return try SSHKey.parse(s, source: source)
            } catch {
                logger.warning("skipping malformed key line: \(error)")
                return nil
            }
        }
    }
}

public enum RemoteKeyFetcherError: Error, Equatable {
    case httpStatus(Int)
}

struct StubFetcher: KeyFetcher {
    let source: KeySource
    let body: String

    func fetch(username: String) async throws -> [SSHKey] {
        RemoteKeyFetcher.parseBody(body, source: source, logger: Logger(label: "test"))
    }
}
