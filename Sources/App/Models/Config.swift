import Foundation
import Yams

/// Runtime configuration for SSHPortal.
///
/// Built from the process environment via ``fromEnvironment(env:)``.
/// Environment overrides defaults; a non-empty `keys.yaml` `title:` can
/// further override the default title (env still wins).
public struct Config: Sendable {
    public var host: String
    public var port: Int
    public var baseURL: String
    public var title: String
    public var themeColor: String
    public var refreshInterval: Int
    public var logLevel: String
    public var keysFile: String

    public init(
        host: String,
        port: Int,
        baseURL: String,
        title: String,
        themeColor: String,
        refreshInterval: Int,
        logLevel: String,
        keysFile: String
    ) {
        self.host = host
        self.port = port
        self.baseURL = baseURL
        self.title = title
        self.themeColor = themeColor
        self.refreshInterval = refreshInterval
        self.logLevel = logLevel
        self.keysFile = keysFile
    }

    public static let testDefault = Config(
        host: "127.0.0.1",
        port: 0,
        baseURL: "http://localhost:8080",
        title: "sshportal",
        themeColor: "#00FF41",
        refreshInterval: 0,
        logLevel: "info",
        keysFile: ""
    )

    public static func fromEnvironment(env: [String: String]) -> Config {
        Config(
            host: env["HOST"] ?? "0.0.0.0",
            port: env["PORT"].flatMap(Int.init) ?? 8080,
            baseURL: env["BASE_URL"] ?? "http://localhost:8080",
            title: env["TITLE"] ?? "sshportal",
            themeColor: env["THEME_COLOR"] ?? "#00FF41",
            refreshInterval: env["REFRESH_INTERVAL"].flatMap(Int.init) ?? 3600,
            logLevel: env["LOG_LEVEL"] ?? "info",
            keysFile: env["KEYS_FILE"] ?? "/config/keys.yaml"
        )
    }
}

/// On-disk schema for `keys.yaml` — a list of remote usernames plus an
/// optional list of inline manual keys.
public struct KeysFile: Sendable, Codable {
    public struct ManualEntry: Sendable, Codable {
        public var comment: String?
        public var type: String?
        public var key: String

        public init(comment: String? = nil, type: String? = nil, key: String) {
            self.comment = comment
            self.type = type
            self.key = key
        }
    }

    public struct Sources: Sendable, Codable {
        public var github: [String]
        public var gitlab: [String]
        public var manual: [ManualEntry]

        public init(github: [String] = [], gitlab: [String] = [], manual: [ManualEntry] = []) {
            self.github = github
            self.gitlab = gitlab
            self.manual = manual
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.github = (try? c.decode([String].self, forKey: .github)) ?? []
            self.gitlab = (try? c.decode([String].self, forKey: .gitlab)) ?? []
            self.manual = (try? c.decode([ManualEntry].self, forKey: .manual)) ?? []
        }

        enum CodingKeys: String, CodingKey { case github, gitlab, manual }
    }

    public var title: String?
    public var sources: Sources

    public init(title: String? = nil, sources: Sources = .init()) {
        self.title = title
        self.sources = sources
    }

    public static func parse(_ yaml: String) throws -> KeysFile {
        let decoder = YAMLDecoder()
        return try decoder.decode(KeysFile.self, from: yaml)
    }

    public static func load(path: String) throws -> KeysFile {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "KeysFile", code: 1, userInfo: [NSLocalizedDescriptionKey: "non-utf8 yaml"])
        }
        return try parse(text)
    }
}
