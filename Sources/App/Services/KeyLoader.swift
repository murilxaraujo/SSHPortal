import Foundation
import Logging

/// Combines manual keys from `keys.yaml` with remote ``KeyFetcher``
/// results into a single flat list.
///
/// The result is intentionally unsorted and may contain duplicates — that
/// work is delegated to ``KeyStore``'s `replaceAll`. Failure of any one
/// remote source is logged at warning level; the loader continues with
/// whatever else succeeded.
public struct KeyLoader: Sendable {
    public let file: KeysFile
    public let github: any KeyFetcher
    public let gitlab: any KeyFetcher
    public let logger: Logger

    public init(
        file: KeysFile,
        github: any KeyFetcher,
        gitlab: any KeyFetcher,
        logger: Logger = Logger(label: "loader")
    ) {
        self.file = file
        self.github = github
        self.gitlab = gitlab
        self.logger = logger
    }

    public func loadAll() async throws -> [SSHKey] {
        var keys: [SSHKey] = []

        for entry in file.sources.manual {
            do {
                keys.append(try SSHKey.parse(entry.key, source: .manual))
            } catch {
                logger.warning("invalid manual key (\(entry.comment ?? "no-comment")): \(error)")
            }
        }

        for username in file.sources.github {
            do {
                let fetched = try await github.fetch(username: username)
                keys.append(contentsOf: fetched)
            } catch {
                logger.warning("github fetch failed for \(username): \(error)")
            }
        }

        for username in file.sources.gitlab {
            do {
                let fetched = try await gitlab.fetch(username: username)
                keys.append(contentsOf: fetched)
            } catch {
                logger.warning("gitlab fetch failed for \(username): \(error)")
            }
        }

        return keys
    }
}
