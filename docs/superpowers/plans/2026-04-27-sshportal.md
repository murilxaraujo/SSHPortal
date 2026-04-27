# SSHPortal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-hosted, single-user SSH public key distribution portal that serves keys via HTTP for `curl >> ~/.ssh/authorized_keys` and renders a terminal-themed web UI.

**Architecture:** Hummingbird 2.x HTTP server in Swift that loads keys from a YAML config file plus optional GitHub/GitLab `.keys` endpoints. An in-memory KeyStore holds deduplicated keys, refreshed on a configurable interval. Three public read-only routes: `GET /` (HTML), `GET /keys` (text), `GET /keys/:type` (filtered text), plus `GET /health` (JSON). Containerized with the Apple Swift Container Plugin and a fallback Dockerfile, published to ghcr.io.

**Tech Stack:** Swift 6.x, Hummingbird 2.x, AsyncHTTPClient, Yams (YAML), swift-log, Swift Testing, swift-container-plugin, Docker, GitHub Actions.

**Pre-decided open questions (Section 13):**
- **License:** MIT (maximum adoption).
- **Project name:** SSHPortal (keeps working title).
- **Key comments:** Preserve comments from GitHub/GitLab keys verbatim (`<key> <comment>` is what GitHub returns; keep it).
- **Light mode:** Deferred to v1.1.
- **Favicon:** A 32x32 SVG terminal-prompt glyph (`>_`) tinted with `THEME_COLOR`.

---

## File Structure

```
sshportal/
├── Package.swift
├── Package.resolved                    # generated
├── Sources/
│   ├── App/
│   │   ├── App.swift                   # @main entry point
│   │   ├── ServerBuilder.swift         # builds Hummingbird router from Config + KeyStore
│   │   ├── Models/
│   │   │   ├── SSHKey.swift            # SSHKey struct, SSHKeyType enum, KeySource enum, parsing
│   │   │   └── Config.swift            # Config struct, env loader, YAML schema decode
│   │   ├── Services/
│   │   │   ├── KeyStore.swift          # actor: load/cache/dedupe, refresh task
│   │   │   ├── KeyFetcher.swift        # protocol + RemoteKeyFetcher (shared GH/GL impl)
│   │   │   └── RateLimiter.swift       # in-memory per-IP token bucket middleware
│   │   ├── Routes/
│   │   │   ├── KeyRoutes.swift         # GET /keys, /keys/:type, /health
│   │   │   └── WebRoutes.swift         # GET /, /favicon.svg, /style.css
│   │   └── Views/
│   │       ├── IndexView.swift         # renders HTML for /
│   │       ├── style.css.swift         # Swift string with the CSS (templated with THEME_COLOR)
│   │       └── favicon.svg.swift       # Swift string with the SVG (templated with THEME_COLOR)
├── Tests/
│   └── AppTests/
│       ├── SSHKeyTests.swift           # parsing, fingerprint, dedupe
│       ├── ConfigTests.swift           # YAML + env loading
│       ├── KeyFetcherTests.swift       # mocked HTTP responses
│       ├── KeyStoreTests.swift         # merge + dedupe + refresh
│       └── RouteTests.swift            # end-to-end against in-memory app
├── config/
│   └── keys.example.yaml
├── scripts/
│   └── install.sh
├── .github/
│   └── workflows/
│       ├── ci.yml                      # build + test on PR
│       └── release.yml                 # tag → build + push image to ghcr.io
├── Dockerfile
├── .dockerignore
├── .gitignore
├── LICENSE                              # MIT
└── README.md
```

**File responsibilities:**

- `App.swift` — only parses env, builds Config, starts `ServerBuilder.makeApp()`. Tiny.
- `ServerBuilder.swift` — composes router, middleware, KeyStore, fetchers. Pure factory; testable.
- `Models/` — value types only. No I/O.
- `Services/KeyStore.swift` — the only mutable state holder. An `actor`.
- `Services/KeyFetcher.swift` — `protocol KeyFetcher { func fetch(username: String) async throws -> [String] }` plus a `RemoteKeyFetcher` that is parameterized by base URL and source enum (so GitHub and GitLab share one impl).
- `Routes/` — pure functions on `(Request, KeyStore) -> Response`.
- `Views/` — string-templated HTML/CSS/SVG. No JS framework, no build step.

---

## Conventions for every task

- **TDD:** write the failing test first, run it, confirm the failure, then write code.
- **Frequent commits:** every task ends with a commit. Commit messages use Conventional Commits.
- **Pin everything:** `Package.resolved` is committed.
- **No premature abstraction:** if a protocol has only one implementation, inline it. The plan only abstracts `KeyFetcher` because it has two real implementations + a test mock.
- **Run from repo root:** all `swift` commands assume CWD is `/Users/murilo/Developer/SSHPortal`.

---

## Phase 1 — Skeleton Server

### Task 1.1: Initial repo bootstrap

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md` (stub)

- [ ] **Step 1: Write `.gitignore`**

```
.build/
.swiftpm/
Package.resolved.bak
*.xcodeproj/
.DS_Store
*.log
```

- [ ] **Step 2: Write `LICENSE`** (MIT, year 2026, holder "Murilo Araujo"). Use the standard MIT template verbatim.

- [ ] **Step 3: Write `README.md` stub**

```markdown
# SSHPortal

Self-hosted SSH public key distribution portal.

Status: under construction. See `docs/superpowers/plans/2026-04-27-sshportal.md`.
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore LICENSE README.md docs/
git commit -m "chore: bootstrap repo with license, gitignore, plan"
```

---

### Task 1.2: `Package.swift` with Hummingbird

**Files:**
- Create: `Package.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "sshportal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ]
        )
    ]
)
```

- [ ] **Step 2: Resolve dependencies**

Run: `swift package resolve`
Expected: `Package.resolved` is created. No errors.

- [ ] **Step 3: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "chore: add swift package manifest with hummingbird"
```

---

### Task 1.3: Minimal app boots and serves `/health`

**Files:**
- Create: `Sources/App/App.swift`
- Create: `Sources/App/ServerBuilder.swift`
- Create: `Sources/App/Routes/KeyRoutes.swift`
- Create: `Tests/AppTests/RouteTests.swift`

- [ ] **Step 1: Write the failing test** (`Tests/AppTests/RouteTests.swift`)

```swift
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
}
```

- [ ] **Step 2: Run test, confirm it fails**

Run: `swift test --filter RouteTests.healthEndpointReturnsOK`
Expected: compile error — `ServerBuilder`, `Config.testDefault`, `KeyStore.empty()` don't exist yet.

- [ ] **Step 3: Write `Config` stub** (`Sources/App/Models/Config.swift`)

```swift
import Foundation

public struct Config: Sendable {
    public var host: String
    public var port: Int
    public var baseURL: String
    public var title: String
    public var themeColor: String
    public var refreshInterval: Int
    public var logLevel: String
    public var keysFile: String

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
}
```

- [ ] **Step 4: Write `KeyStore.empty()` stub** (`Sources/App/Services/KeyStore.swift`)

```swift
import Foundation

public actor KeyStore {
    private var keys: [SSHKey] = []
    private(set) public var lastRefresh: Date?

    public init(initialKeys: [SSHKey] = []) {
        self.keys = initialKeys
    }

    public static func empty() -> KeyStore { KeyStore() }

    public func all() -> [SSHKey] { keys }
    public func filtered(by type: SSHKeyType) -> [SSHKey] { keys.filter { $0.type == type } }
    public func count() -> Int { keys.count }
}
```

- [ ] **Step 5: Write `SSHKey` placeholder enough to compile** (`Sources/App/Models/SSHKey.swift`)

```swift
import Foundation

public enum SSHKeyType: String, Sendable, CaseIterable {
    case ed25519, rsa, ecdsa
    case ecdsaSK = "ecdsa-sk"
    case ed25519SK = "ed25519-sk"
}

public enum KeySource: String, Sendable {
    case github, gitlab, manual
}

public struct SSHKey: Sendable, Hashable {
    public let type: SSHKeyType
    public let publicKey: String
    public let comment: String?
    public let source: KeySource
    public let fingerprint: String
}
```

- [ ] **Step 6: Write `KeyRoutes` with `/health`** (`Sources/App/Routes/KeyRoutes.swift`)

```swift
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
```

- [ ] **Step 7: Write `ServerBuilder`** (`Sources/App/ServerBuilder.swift`)

```swift
import Hummingbird
import Logging

public enum ServerBuilder {
    public static func makeApp(config: Config, keyStore: KeyStore) throws -> some ApplicationProtocol {
        var logger = Logger(label: "sshportal")
        logger.logLevel = .info
        let router = Router()
        KeyRoutes.register(router, store: keyStore)
        return Application(
            router: router,
            configuration: .init(
                address: .hostname(config.host, port: config.port),
                serverName: "sshportal"
            ),
            logger: logger
        )
    }
}
```

- [ ] **Step 8: Write `App.swift`** (`Sources/App/App.swift`)

```swift
import Hummingbird

@main
struct AppMain {
    static func main() async throws {
        let config = Config.testDefault
        let store = KeyStore.empty()
        let app = try ServerBuilder.makeApp(config: config, keyStore: store)
        try await app.runService()
    }
}
```

- [ ] **Step 9: Run test, confirm pass**

Run: `swift test --filter RouteTests.healthEndpointReturnsOK`
Expected: 1 test passed.

- [ ] **Step 10: Commit**

```bash
git add Sources Tests
git commit -m "feat: skeleton hummingbird server with /health"
```

---

### Task 1.4: `/keys` returns hardcoded keys as plain text (will be replaced)

**Files:**
- Modify: `Sources/App/Routes/KeyRoutes.swift`
- Modify: `Tests/AppTests/RouteTests.swift`

- [ ] **Step 1: Add the failing test** (append to `RouteTests.swift`)

```swift
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
            #expect(response.headers[.contentType]?.starts(with: "text/plain") == true)
            let body = String(buffer: response.body)
            #expect(body == "ssh-ed25519 AAAA test@example\n")
        }
    }
}
```

- [ ] **Step 2: Run, confirm it fails (404)**

Run: `swift test --filter RouteTests.keysEndpointReturnsPlainText`
Expected: FAIL — endpoint not registered.

- [ ] **Step 3: Add `/keys` route** (in `KeyRoutes.register`, after `/health`)

```swift
router.get("/keys") { _, _ -> Response in
    let keys = await store.all()
    let body = keys.map(\.publicKey).joined(separator: "\n") + (keys.isEmpty ? "" : "\n")
    var response = Response(
        status: .ok,
        headers: [.contentType: "text/plain; charset=utf-8"],
        body: ResponseBody(byteBuffer: .init(string: body))
    )
    response.headers[.cacheControl] = "no-store"
    return response
}
```

- [ ] **Step 4: Run, confirm it passes**

Run: `swift test --filter RouteTests.keysEndpointReturnsPlainText`
Expected: PASS.

- [ ] **Step 5: Manual smoke test**

Run: `swift run App &` then `curl -s http://localhost:8080/health`
Expected: JSON like `{"status":"ok","keys_loaded":0}`.
Stop the server: `kill %1`.

- [ ] **Step 6: Commit**

```bash
git add Sources Tests
git commit -m "feat: add GET /keys plain-text endpoint"
```

---

## Phase 2 — Config & Key Loading

### Task 2.1: SSHKey parsing + fingerprint

**Files:**
- Modify: `Sources/App/Models/SSHKey.swift`
- Create: `Tests/AppTests/SSHKeyTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import App

@Suite struct SSHKeyTests {
    @Test func parsesEd25519() throws {
        let line = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleData murilo@laptop"
        let key = try SSHKey.parse(line, source: .manual)
        #expect(key.type == .ed25519)
        #expect(key.comment == "murilo@laptop")
        #expect(key.publicKey == line)
    }

    @Test func parsesRSA() throws {
        let key = try SSHKey.parse("ssh-rsa AAAAB3NzaC1yc2E key@host", source: .github)
        #expect(key.type == .rsa)
        #expect(key.source == .github)
    }

    @Test func parsesEcdsa() throws {
        let key = try SSHKey.parse("ecdsa-sha2-nistp256 AAAA key@host", source: .manual)
        #expect(key.type == .ecdsa)
    }

    @Test func parsesEcdsaSK() throws {
        let key = try SSHKey.parse("sk-ecdsa-sha2-nistp256@openssh.com AAAAInN key@yk", source: .manual)
        #expect(key.type == .ecdsaSK)
    }

    @Test func parsesEd25519SK() throws {
        let key = try SSHKey.parse("sk-ssh-ed25519@openssh.com AAAA key@yk", source: .manual)
        #expect(key.type == .ed25519SK)
    }

    @Test func rejectsEmpty() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("", source: .manual)
        }
    }

    @Test func rejectsUnknownPrefix() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("nonsense AAAA host", source: .manual)
        }
    }

    @Test func rejectsMissingBlob() {
        #expect(throws: SSHKey.ParseError.self) {
            _ = try SSHKey.parse("ssh-ed25519", source: .manual)
        }
    }

    @Test func fingerprintIsStable() throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA host", source: .github)
        let b = try SSHKey.parse("ssh-ed25519 AAAA other-host", source: .gitlab)
        // Same blob, different comments and sources → same fingerprint
        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint.hasPrefix("SHA256:"))
    }

    @Test func fingerprintDiffersForDifferentBlobs() throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA host", source: .manual)
        let b = try SSHKey.parse("ssh-ed25519 BBBB host", source: .manual)
        #expect(a.fingerprint != b.fingerprint)
    }
}
```

- [ ] **Step 2: Run, confirm fail**

Run: `swift test --filter SSHKeyTests`
Expected: compile error — `SSHKey.parse`, `SSHKey.ParseError` undefined.

- [ ] **Step 3: Implement parsing in `SSHKey.swift`** (replace existing struct)

```swift
import Foundation
import Crypto

public enum SSHKeyType: String, Sendable, CaseIterable, Codable {
    case ed25519, rsa, ecdsa
    case ecdsaSK = "ecdsa-sk"
    case ed25519SK = "ed25519-sk"

    public var displayName: String {
        switch self {
        case .ed25519: return "ED25519"
        case .rsa: return "RSA"
        case .ecdsa: return "ECDSA"
        case .ecdsaSK: return "ECDSA-SK"
        case .ed25519SK: return "ED25519-SK"
        }
    }

    static func from(prefix: String) -> SSHKeyType? {
        switch prefix {
        case "ssh-ed25519": return .ed25519
        case "ssh-rsa": return .rsa
        case _ where prefix.hasPrefix("ecdsa-sha2-"): return .ecdsa
        case _ where prefix.hasPrefix("sk-ecdsa-sha2-"): return .ecdsaSK
        case _ where prefix.hasPrefix("sk-ssh-ed25519"): return .ed25519SK
        default: return nil
        }
    }
}

public enum KeySource: String, Sendable, Codable {
    case github, gitlab, manual
}

public struct SSHKey: Sendable, Hashable, Codable {
    public let type: SSHKeyType
    public let publicKey: String
    public let comment: String?
    public let source: KeySource
    public let fingerprint: String

    public enum ParseError: Error, Equatable {
        case empty
        case unknownType(String)
        case missingBlob
    }

    public static func parse(_ line: String, source: KeySource) throws -> SSHKey {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else { throw ParseError.missingBlob }
        let prefix = String(parts[0])
        let blob = String(parts[1])
        guard let type = SSHKeyType.from(prefix: prefix) else {
            throw ParseError.unknownType(prefix)
        }
        let comment: String? = parts.count == 3 ? String(parts[2]) : nil
        let fp = Self.fingerprint(of: blob)
        return SSHKey(type: type, publicKey: trimmed, comment: comment, source: source, fingerprint: fp)
    }

    static func fingerprint(of base64Blob: String) -> String {
        guard let data = Data(base64Encoded: base64Blob) else {
            // Fall back to hashing the raw string — tests use non-real base64
            let digest = SHA256.hash(data: Data(base64Blob.utf8))
            return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
        }
        let digest = SHA256.hash(data: data)
        return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}
```

- [ ] **Step 4: Add `swift-crypto` dependency** (Package.swift)

Add to `dependencies`:
```swift
.package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
```
Add to App target dependencies:
```swift
.product(name: "Crypto", package: "swift-crypto"),
```

Run: `swift package resolve`

- [ ] **Step 5: Run tests, confirm pass**

Run: `swift test --filter SSHKeyTests`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources Tests Package.swift Package.resolved
git commit -m "feat: SSHKey parsing with type detection and SHA256 fingerprint"
```

---

### Task 2.2: Config loading from env + YAML

**Files:**
- Modify: `Sources/App/Models/Config.swift`
- Create: `Tests/AppTests/ConfigTests.swift`
- Create: `config/keys.example.yaml`

- [ ] **Step 1: Write `keys.example.yaml`**

```yaml
title: "your-handle"

sources:
  github:
    - your-github-username

  gitlab:
    - your-gitlab-username

  manual:
    - comment: "Work laptop"
      type: ed25519
      key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host"
```

- [ ] **Step 2: Write failing tests** (`Tests/AppTests/ConfigTests.swift`)

```swift
import Testing
import Foundation
@testable import App

@Suite struct ConfigTests {
    @Test func loadsDefaultsWhenNoEnv() {
        let config = Config.fromEnvironment(env: [:])
        #expect(config.port == 8080)
        #expect(config.host == "0.0.0.0")
        #expect(config.title == "sshportal")
        #expect(config.themeColor == "#00FF41")
        #expect(config.refreshInterval == 3600)
        #expect(config.keysFile == "/config/keys.yaml")
    }

    @Test func overridesFromEnv() {
        let config = Config.fromEnvironment(env: [
            "PORT": "9090",
            "TITLE": "murilo",
            "THEME_COLOR": "#FFAA00",
            "REFRESH_INTERVAL": "60",
            "KEYS_FILE": "/tmp/k.yaml"
        ])
        #expect(config.port == 9090)
        #expect(config.title == "murilo")
        #expect(config.themeColor == "#FFAA00")
        #expect(config.refreshInterval == 60)
        #expect(config.keysFile == "/tmp/k.yaml")
    }

    @Test func parsesYamlConfig() throws {
        let yaml = """
        title: murilxaraujo
        sources:
          github:
            - murilxaraujo
          gitlab:
            - murilxaraujo
          manual:
            - comment: Yubikey
              type: ecdsa-sk
              key: "sk-ecdsa-sha2-nistp256@openssh.com AAAAA yk@laptop"
        """
        let parsed = try KeysFile.parse(yaml)
        #expect(parsed.title == "murilxaraujo")
        #expect(parsed.sources.github == ["murilxaraujo"])
        #expect(parsed.sources.gitlab == ["murilxaraujo"])
        #expect(parsed.sources.manual.count == 1)
        #expect(parsed.sources.manual[0].comment == "Yubikey")
    }

    @Test func emptySourcesYamlAllowed() throws {
        let parsed = try KeysFile.parse("title: x\nsources: {}\n")
        #expect(parsed.title == "x")
        #expect(parsed.sources.github.isEmpty)
        #expect(parsed.sources.gitlab.isEmpty)
        #expect(parsed.sources.manual.isEmpty)
    }
}
```

- [ ] **Step 3: Run, confirm fail**

Run: `swift test --filter ConfigTests`
Expected: compile error.

- [ ] **Step 4: Implement `Config.swift`**

```swift
import Foundation
import Yams

public struct Config: Sendable {
    public var host: String
    public var port: Int
    public var baseURL: String
    public var title: String
    public var themeColor: String
    public var refreshInterval: Int
    public var logLevel: String
    public var keysFile: String

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

public struct KeysFile: Sendable, Codable {
    public struct ManualEntry: Sendable, Codable {
        public var comment: String?
        public var type: String?
        public var key: String
    }

    public struct Sources: Sendable, Codable {
        public var github: [String] = []
        public var gitlab: [String] = []
        public var manual: [ManualEntry] = []
    }

    public var title: String?
    public var sources: Sources

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
```

- [ ] **Step 5: Run tests, confirm pass**

Run: `swift test --filter ConfigTests`

- [ ] **Step 6: Commit**

```bash
git add Sources Tests config
git commit -m "feat: Config from env + YAML keys file parsing"
```

---

### Task 2.3: KeyFetcher protocol + remote fetcher

**Files:**
- Create: `Sources/App/Services/KeyFetcher.swift`
- Create: `Tests/AppTests/KeyFetcherTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import App

@Suite struct KeyFetcherTests {
    @Test func parsesMultipleKeysFromBody() async throws {
        let body = """
        ssh-ed25519 AAAA host1
        ssh-rsa BBBB host2

        sk-ssh-ed25519@openssh.com CCCC yk
        """
        let fetcher = StubFetcher(source: .github, body: body)
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.count == 3)
        #expect(keys[0].type == .ed25519)
        #expect(keys[1].type == .rsa)
        #expect(keys[2].type == .ed25519SK)
        #expect(keys.allSatisfy { $0.source == .github })
    }

    @Test func skipsMalformedLines() async throws {
        let body = "ssh-ed25519 AAAA ok\nnonsense line\n"
        let fetcher = StubFetcher(source: .gitlab, body: body)
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.count == 1)
        #expect(keys[0].source == .gitlab)
    }

    @Test func emptyBodyReturnsEmpty() async throws {
        let fetcher = StubFetcher(source: .github, body: "")
        let keys = try await fetcher.fetch(username: "anyone")
        #expect(keys.isEmpty)
    }
}
```

- [ ] **Step 2: Run, confirm fail**

- [ ] **Step 3: Implement `KeyFetcher.swift`**

```swift
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

    public init(source: KeySource, baseURL: String, httpClient: HTTPClient, logger: Logger, timeoutSeconds: Int64 = 10) {
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

// Test helper that bypasses HTTP and parses a canned body.
struct StubFetcher: KeyFetcher {
    let source: KeySource
    let body: String

    func fetch(username: String) async throws -> [SSHKey] {
        RemoteKeyFetcher.parseBody(body, source: source, logger: Logger(label: "test"))
    }
}
```

- [ ] **Step 4: Run, confirm pass**

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: KeyFetcher protocol with remote .keys URL fetcher"
```

---

### Task 2.4: KeyStore deduplication and merge

**Files:**
- Modify: `Sources/App/Services/KeyStore.swift`
- Create: `Tests/AppTests/KeyStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import App

@Suite struct KeyStoreTests {
    private func key(_ blob: String, _ source: KeySource, _ comment: String? = nil) -> SSHKey {
        try! SSHKey.parse("ssh-ed25519 \(blob) \(comment ?? "")".trimmingCharacters(in: .whitespaces), source: source)
    }

    @Test func dedupesByFingerprintWithManualWinning() async {
        let m = key("AAAA", .manual, "manual-key")
        let g = key("AAAA", .github, "github-key")
        let store = KeyStore.empty()
        await store.replaceAll([g, m]) // insert in non-priority order
        let result = await store.all()
        #expect(result.count == 1)
        #expect(result[0].source == .manual)
        #expect(result[0].comment == "manual-key")
    }

    @Test func dedupePrioritizesGithubOverGitlab() async {
        let g = key("BBBB", .github, "gh")
        let l = key("BBBB", .gitlab, "gl")
        let store = KeyStore.empty()
        await store.replaceAll([l, g])
        let result = await store.all()
        #expect(result.count == 1)
        #expect(result[0].source == .github)
    }

    @Test func filteredByType() async throws {
        let a = try SSHKey.parse("ssh-ed25519 AAAA a", source: .manual)
        let b = try SSHKey.parse("ssh-rsa BBBB b", source: .manual)
        let store = KeyStore.empty()
        await store.replaceAll([a, b])
        let ed = await store.filtered(by: .ed25519)
        #expect(ed.count == 1)
        #expect(ed[0].type == .ed25519)
    }

    @Test func sortedByPriorityThenType() async throws {
        // Manual keys appear before remote, ed25519 before rsa within same source.
        let m1 = try SSHKey.parse("ssh-rsa MMMM m-rsa", source: .manual)
        let m2 = try SSHKey.parse("ssh-ed25519 NNNN m-ed", source: .manual)
        let g1 = try SSHKey.parse("ssh-ed25519 GGGG g-ed", source: .github)
        let store = KeyStore.empty()
        await store.replaceAll([g1, m1, m2])
        let result = await store.all()
        #expect(result.count == 3)
        #expect(result[0].source == .manual)
        #expect(result[1].source == .manual)
        #expect(result[2].source == .github)
    }
}
```

- [ ] **Step 2: Run, confirm fail** — `replaceAll` doesn't exist.

- [ ] **Step 3: Update `KeyStore.swift`**

```swift
import Foundation

public actor KeyStore {
    private var keys: [SSHKey] = []
    public private(set) var lastRefresh: Date?

    public init(initialKeys: [SSHKey] = []) {
        self.keys = Self.merge(initialKeys)
        if !initialKeys.isEmpty { self.lastRefresh = Date() }
    }

    public static func empty() -> KeyStore { KeyStore() }

    public func all() -> [SSHKey] { keys }
    public func filtered(by type: SSHKeyType) -> [SSHKey] { keys.filter { $0.type == type } }
    public func count() -> Int { keys.count }

    public func replaceAll(_ newKeys: [SSHKey]) {
        keys = Self.merge(newKeys)
        lastRefresh = Date()
    }

    static func merge(_ input: [SSHKey]) -> [SSHKey] {
        // Priority: manual > github > gitlab. First occurrence (after sorting by priority) wins.
        let priority: (KeySource) -> Int = {
            switch $0 { case .manual: 0; case .github: 1; case .gitlab: 2 }
        }
        let typePriority: (SSHKeyType) -> Int = {
            switch $0 {
            case .ed25519: 0; case .ed25519SK: 1; case .ecdsaSK: 2; case .ecdsa: 3; case .rsa: 4
            }
        }
        let sorted = input.sorted { lhs, rhs in
            let lp = priority(lhs.source), rp = priority(rhs.source)
            if lp != rp { return lp < rp }
            let lt = typePriority(lhs.type), rt = typePriority(rhs.type)
            if lt != rt { return lt < rt }
            return lhs.fingerprint < rhs.fingerprint
        }
        var seen = Set<String>()
        var output: [SSHKey] = []
        for k in sorted where !seen.contains(k.fingerprint) {
            seen.insert(k.fingerprint)
            output.append(k)
        }
        return output
    }
}
```

- [ ] **Step 4: Run, confirm pass**

Run: `swift test --filter KeyStoreTests`

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: KeyStore dedupe and source-priority merge"
```

---

### Task 2.5: Loader that combines YAML + remote fetchers

**Files:**
- Create: `Sources/App/Services/KeyLoader.swift`
- Modify: `Tests/AppTests/KeyStoreTests.swift` (append)

- [ ] **Step 1: Add failing test (in `KeyStoreTests.swift`)**

```swift
@Test func loaderMergesManualAndRemote() async throws {
    let yaml = """
    title: t
    sources:
      github:
        - alice
      gitlab: []
      manual:
        - comment: Local
          key: "ssh-ed25519 LOCALKEY local@host"
    """
    let file = try KeysFile.parse(yaml)
    let stubGH = StubFetcher(source: .github, body: "ssh-ed25519 GHKEY alice@gh\nssh-rsa GHRSA alice@gh\n")
    let stubGL = StubFetcher(source: .gitlab, body: "")
    let loader = KeyLoader(file: file, github: stubGH, gitlab: stubGL)
    let keys = try await loader.loadAll()
    #expect(keys.count == 3)
    #expect(keys.contains { $0.publicKey.contains("LOCALKEY") })
    #expect(keys.contains { $0.publicKey.contains("GHKEY") })
}
```

- [ ] **Step 2: Run, confirm fail**

- [ ] **Step 3: Implement `KeyLoader.swift`**

```swift
import Foundation
import Logging

public struct KeyLoader: Sendable {
    public let file: KeysFile
    public let github: any KeyFetcher
    public let gitlab: any KeyFetcher
    public let logger: Logger

    public init(file: KeysFile, github: any KeyFetcher, gitlab: any KeyFetcher, logger: Logger = Logger(label: "loader")) {
        self.file = file
        self.github = github
        self.gitlab = gitlab
        self.logger = logger
    }

    public func loadAll() async throws -> [SSHKey] {
        var keys: [SSHKey] = []

        // Manual keys first
        for entry in file.sources.manual {
            do {
                keys.append(try SSHKey.parse(entry.key, source: .manual))
            } catch {
                logger.warning("invalid manual key (\(entry.comment ?? "no-comment")): \(error)")
            }
        }

        // GitHub
        for username in file.sources.github {
            do {
                let fetched = try await github.fetch(username: username)
                keys.append(contentsOf: fetched)
            } catch {
                logger.warning("github fetch failed for \(username): \(error)")
            }
        }

        // GitLab
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
```

- [ ] **Step 4: Run, confirm pass**

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: KeyLoader merging YAML manual + remote fetchers"
```

---

### Task 2.6: Refresh task on KeyStore

**Files:**
- Modify: `Sources/App/Services/KeyStore.swift`
- Modify: `Tests/AppTests/KeyStoreTests.swift`

- [ ] **Step 1: Add failing test**

```swift
@Test func refreshOnceCallsLoader() async throws {
    let file = try KeysFile.parse("title: t\nsources:\n  manual:\n    - key: \"ssh-ed25519 AAAA m\"")
    let loader = KeyLoader(file: file, github: StubFetcher(source: .github, body: ""), gitlab: StubFetcher(source: .gitlab, body: ""))
    let store = KeyStore.empty()
    await store.refreshOnce(using: loader)
    let keys = await store.all()
    #expect(keys.count == 1)
    #expect(await store.lastRefresh != nil)
}
```

- [ ] **Step 2: Add `refreshOnce` to KeyStore**

```swift
public func refreshOnce(using loader: KeyLoader) async {
    do {
        let keys = try await loader.loadAll()
        replaceAll(keys)
    } catch {
        // loader.loadAll currently doesn't throw, but defensive.
    }
}
```

- [ ] **Step 3: Run, confirm pass**

- [ ] **Step 4: Commit**

```bash
git add Sources Tests
git commit -m "feat: KeyStore.refreshOnce reloads via KeyLoader"
```

---

### Task 2.7: Wire `/keys/:type` route

**Files:**
- Modify: `Sources/App/Routes/KeyRoutes.swift`
- Modify: `Tests/AppTests/RouteTests.swift`

- [ ] **Step 1: Add failing tests**

```swift
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
```

- [ ] **Step 2: Run, confirm fail**

- [ ] **Step 3: Add the route in `KeyRoutes.register`** (after `/keys`)

```swift
router.get("/keys/:type") { request, _ -> Response in
    let raw = request.parameters.get("type") ?? ""
    guard let type = SSHKeyType(rawValue: raw) else {
        return Response(status: .notFound, headers: [.contentType: "text/plain"], body: ResponseBody(byteBuffer: .init(string: "unknown key type\n")))
    }
    let keys = await store.filtered(by: type)
    let body = keys.map(\.publicKey).joined(separator: "\n") + (keys.isEmpty ? "" : "\n")
    return Response(
        status: .ok,
        headers: [.contentType: "text/plain; charset=utf-8", .cacheControl: "no-store"],
        body: ResponseBody(byteBuffer: .init(string: body))
    )
}
```

- [ ] **Step 4: Run, confirm pass**

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: GET /keys/:type filtered endpoint"
```

---

### Task 2.8: Wire env + YAML + fetchers into `App.swift`

**Files:**
- Modify: `Sources/App/App.swift`
- Modify: `Sources/App/ServerBuilder.swift`

- [ ] **Step 1: Update `ServerBuilder.makeApp`** to accept a `KeyLoader?` and start the refresh background task on app start

```swift
public enum ServerBuilder {
    public static func makeApp(
        config: Config,
        keyStore: KeyStore,
        loader: KeyLoader? = nil
    ) throws -> some ApplicationProtocol {
        var logger = Logger(label: "sshportal")
        logger.logLevel = Logger.Level(rawValue: config.logLevel) ?? .info

        let router = Router()
        KeyRoutes.register(router, store: keyStore)

        var app = Application(
            router: router,
            configuration: .init(
                address: .hostname(config.host, port: config.port),
                serverName: "sshportal"
            ),
            logger: logger
        )
        if let loader, config.refreshInterval >= 0 {
            app.addServices(RefreshService(store: keyStore, loader: loader, intervalSeconds: config.refreshInterval, logger: logger))
        }
        return app
    }
}

public struct RefreshService: Service {
    public let store: KeyStore
    public let loader: KeyLoader
    public let intervalSeconds: Int
    public let logger: Logger

    public func run() async throws {
        // Initial load
        await store.refreshOnce(using: loader)
        logger.info("initial keys loaded: \(await store.count())")
        guard intervalSeconds > 0 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(intervalSeconds))
            if Task.isCancelled { break }
            await store.refreshOnce(using: loader)
            logger.info("keys refreshed: \(await store.count())")
        }
    }
}
```

(`Service` comes from `ServiceLifecycle`; Hummingbird re-exports it. If not, add `swift-service-lifecycle` as a dep — confirm by `swift build`.)

- [ ] **Step 2: Update `App.swift`** to load env + YAML + start fetchers

```swift
import Hummingbird
import AsyncHTTPClient
import Logging
import Foundation

@main
struct AppMain {
    static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        let config = Config.fromEnvironment(env: env)
        var logger = Logger(label: "sshportal")
        logger.logLevel = Logger.Level(rawValue: config.logLevel) ?? .info

        let file: KeysFile
        do {
            file = try KeysFile.load(path: config.keysFile)
        } catch {
            logger.warning("could not load \(config.keysFile): \(error). Starting with empty config.")
            file = KeysFile(title: nil, sources: .init())
        }

        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? httpClient.syncShutdown() }

        let github = RemoteKeyFetcher(source: .github, baseURL: "https://github.com", httpClient: httpClient, logger: logger)
        let gitlab = RemoteKeyFetcher(source: .gitlab, baseURL: "https://gitlab.com", httpClient: httpClient, logger: logger)
        let loader = KeyLoader(file: file, github: github, gitlab: gitlab, logger: logger)

        let store = KeyStore.empty()
        let app = try ServerBuilder.makeApp(config: config, keyStore: store, loader: loader)
        try await app.runService()
    }
}
```

- [ ] **Step 3: Build, fix any compile errors**

Run: `swift build 2>&1 | tail -30`
Expected: build succeeds. If `Service` import needed, add `import ServiceLifecycle` and the dep.

- [ ] **Step 4: Run all tests**

Run: `swift test`
Expected: all pass.

- [ ] **Step 5: Smoke test against a real config**

Create `config/keys.test.yaml`:
```yaml
title: smoketest
sources:
  manual:
    - comment: smoke
      key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY smoke@local"
```

Run:
```
KEYS_FILE=config/keys.test.yaml swift run App &
sleep 2
curl -sf http://localhost:8080/keys
curl -sf http://localhost:8080/keys/ed25519
curl -sf http://localhost:8080/health
kill %1
```
Expected: each endpoint returns the seeded key / health JSON. Then remove `config/keys.test.yaml` (don't commit it).

- [ ] **Step 6: Commit**

```bash
git add Sources
git commit -m "feat: wire env+yaml+fetchers, periodic refresh service"
```

---

## Phase 3 — Web UI

### Task 3.1: HTML page renders title and key count

**Files:**
- Create: `Sources/App/Views/IndexView.swift`
- Create: `Sources/App/Routes/WebRoutes.swift`
- Modify: `Sources/App/ServerBuilder.swift` (register `WebRoutes`)
- Modify: `Tests/AppTests/RouteTests.swift`

- [ ] **Step 1: Add failing test**

```swift
@Test func indexPageRendersTitleAndKeyCount() async throws {
    let key = try SSHKey.parse("ssh-ed25519 AAAA test", source: .manual)
    let store = KeyStore(initialKeys: [key])
    var cfg = Config.testDefault
    cfg.title = "murilxaraujo"
    cfg.baseURL = "https://keys.example.com"
    let app = try ServerBuilder.makeApp(config: cfg, keyStore: store)
    try await app.test(.router) { client in
        try await client.execute(uri: "/", method: .get) { response in
            #expect(response.status == .ok)
            #expect(response.headers[.contentType]?.starts(with: "text/html") == true)
            let body = String(buffer: response.body)
            #expect(body.contains("murilxaraujo"))
            #expect(body.contains("https://keys.example.com/keys"))
            #expect(body.contains("ssh-ed25519"))
        }
    }
}
```

- [ ] **Step 2: Run, confirm fail**

- [ ] **Step 3: Implement `IndexView.swift`**

```swift
import Foundation

public enum IndexView {
    public static func render(config: Config, keys: [SSHKey], lastRefresh: Date?) -> String {
        let title = htmlEscape(config.title)
        let baseURL = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let primary = config.themeColor
        let installCmd = "curl -fs \(baseURL)/keys >> ~/.ssh/authorized_keys"
        let typeOptions = ([("all", "All")] + SSHKeyType.allCases.map { ($0.rawValue, $0.displayName) })
            .map { "<option value=\"\($0.0)\">\($0.1)</option>" }
            .joined()
        let keyRows = keys.map { keyRow($0) }.joined(separator: "\n")
        let lastRefreshStr = lastRefresh.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
        let css = StyleSheet.css(primary: primary)
        let svgFavicon = Favicon.svg(primary: primary)

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title) — sshportal</title>
        <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;utf8,\(percentEscape(svgFavicon))">
        <style>\(css)</style>
        </head>
        <body>
        <main>
          <header>
            <span class="prompt">&gt;_</span>
            <span class="brand">sshportal</span>
          </header>
          <section class="card title-card">
            <h1>SSH keys of <span class="accent">@\(title)</span></h1>
            <p>Public SSH keys for authorizing this account on remote servers. Run the command below on any server you control to append these keys to <code>~/.ssh/authorized_keys</code>.</p>
          </section>
          <section class="card install-card">
            <div class="install-toolbar">
              <label>Filter:
                <select id="type-filter">\(typeOptions)</select>
              </label>
              <button id="copy-btn" type="button">Copy</button>
            </div>
            <pre id="install-cmd" data-base="\(htmlEscape(baseURL))">\(htmlEscape(installCmd))</pre>
          </section>
          <section class="key-list">
            \(keyRows.isEmpty ? "<p class=\"empty\">No keys configured.</p>" : keyRows)
          </section>
          <footer>
            <a href="https://github.com/murilxaraujo/sshportal" rel="noopener">github.com/murilxaraujo/sshportal</a>
            <span class="meta">\(keys.count) keys · last refresh \(lastRefreshStr)</span>
          </footer>
        </main>
        <script>\(IndexScript.js)</script>
        </body>
        </html>
        """
    }

    private static func keyRow(_ k: SSHKey) -> String {
        let badge = htmlEscape(k.type.displayName)
        let comment = htmlEscape(k.comment ?? "")
        let fp = htmlEscape(String(k.fingerprint.prefix(36)) + (k.fingerprint.count > 36 ? "…" : ""))
        let sourceIcon: String = switch k.source {
        case .github: "GH"; case .gitlab: "GL"; case .manual: "··"
        }
        return """
        <article class="key-row" data-type="\(k.type.rawValue)">
          <span class="type-badge">\(badge)</span>
          <span class="fp">\(fp)</span>
          <span class="comment">\(comment)</span>
          <span class="source" title="\(k.source.rawValue)">\(sourceIcon)</span>
        </article>
        """
    }

    static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func percentEscape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(.init(charactersIn: "#"))) ?? s
    }
}
```

- [ ] **Step 4: Implement `StyleSheet`** (`Sources/App/Views/style.css.swift`)

```swift
import Foundation

enum StyleSheet {
    static func css(primary: String) -> String {
        """
        :root { --bg: #0D1117; --fg: #C9D1D9; --muted: #6E7681; --primary: \(primary); --card: #161B22; --border: #30363D; }
        * { box-sizing: border-box; }
        html, body { background: var(--bg); color: var(--fg); margin: 0; padding: 0; font-family: 'JetBrains Mono', 'Fira Code', Menlo, Consolas, monospace; font-size: 14px; line-height: 1.55; }
        main { max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }
        header { display: flex; align-items: center; gap: 12px; margin-bottom: 24px; }
        .prompt { color: var(--primary); font-weight: 700; }
        .brand { color: var(--muted); font-size: 13px; letter-spacing: 0.05em; text-transform: uppercase; }
        .card { background: var(--card); border: 1px solid var(--border); border-radius: 4px; padding: 20px; margin-bottom: 16px; }
        h1 { margin: 0 0 8px; font-size: 18px; font-weight: 500; }
        .accent { color: var(--primary); }
        p { margin: 0; color: var(--muted); }
        .install-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 12px; }
        .install-toolbar label { color: var(--muted); font-size: 12px; }
        .install-toolbar select { background: var(--bg); color: var(--fg); border: 1px solid var(--border); padding: 6px 8px; border-radius: 4px; font-family: inherit; font-size: 12px; }
        #copy-btn { background: var(--primary); color: var(--bg); border: 0; padding: 8px 16px; border-radius: 4px; cursor: pointer; font-family: inherit; font-weight: 600; min-height: 44px; min-width: 88px; }
        #copy-btn:hover { filter: brightness(1.1); }
        #copy-btn.copied { background: var(--fg); }
        pre { background: var(--bg); border: 1px solid var(--border); border-radius: 4px; padding: 12px; margin: 0; overflow-x: auto; color: var(--primary); }
        .key-list { display: flex; flex-direction: column; gap: 8px; }
        .key-row { display: grid; grid-template-columns: 90px 1fr auto auto; gap: 12px; align-items: center; padding: 12px; background: var(--card); border: 1px solid var(--border); border-radius: 4px; }
        .type-badge { display: inline-block; padding: 2px 8px; border: 1px solid var(--primary); color: var(--primary); border-radius: 999px; font-size: 11px; text-align: center; }
        .fp { color: var(--muted); font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .comment { color: var(--fg); font-size: 12px; }
        .source { color: var(--muted); font-size: 11px; letter-spacing: 0.1em; }
        footer { margin-top: 24px; display: flex; justify-content: space-between; color: var(--muted); font-size: 12px; }
        footer a { color: var(--muted); text-decoration: none; border-bottom: 1px dotted var(--muted); }
        footer a:hover { color: var(--primary); border-color: var(--primary); }
        .empty { padding: 24px; text-align: center; color: var(--muted); }
        @media (max-width: 540px) {
          .key-row { grid-template-columns: 70px 1fr auto; }
          .key-row .source { display: none; }
        }
        """
    }
}

enum Favicon {
    static func svg(primary: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" fill="#0D1117"/><text x="50%" y="60%" text-anchor="middle" font-family="monospace" font-size="20" font-weight="700" fill="\(primary)">&gt;_</text></svg>
        """
    }
}

enum IndexScript {
    static let js = #"""
    (function(){
      const sel = document.getElementById('type-filter');
      const cmd = document.getElementById('install-cmd');
      const btn = document.getElementById('copy-btn');
      const base = cmd.getAttribute('data-base');
      function update() {
        const t = sel.value;
        const path = t === 'all' ? '/keys' : '/keys/' + t;
        cmd.textContent = 'curl -fs ' + base + path + ' >> ~/.ssh/authorized_keys';
        document.querySelectorAll('.key-row').forEach(r => {
          r.style.display = (t === 'all' || r.dataset.type === t) ? '' : 'none';
        });
      }
      sel.addEventListener('change', update);
      btn.addEventListener('click', async () => {
        const text = cmd.textContent;
        try {
          await navigator.clipboard.writeText(text);
        } catch (_e) {
          const r = document.createRange(); r.selectNodeContents(cmd);
          const s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
        }
        btn.classList.add('copied');
        const orig = btn.textContent;
        btn.textContent = 'Copied ✓';
        setTimeout(() => { btn.textContent = orig; btn.classList.remove('copied'); }, 2000);
      });
    })();
    """#
}
```

- [ ] **Step 5: Implement `WebRoutes.swift`**

```swift
import Hummingbird
import Foundation

public enum WebRoutes {
    public static func register(_ router: Router<some RequestContext>, store: KeyStore, config: Config) {
        router.get("/") { _, _ -> Response in
            let keys = await store.all()
            let last = await store.lastRefresh
            let html = IndexView.render(config: config, keys: keys, lastRefresh: last)
            return Response(
                status: .ok,
                headers: [
                    .contentType: "text/html; charset=utf-8",
                    .cacheControl: "no-store"
                ],
                body: ResponseBody(byteBuffer: .init(string: html))
            )
        }
    }
}
```

- [ ] **Step 6: Register in `ServerBuilder.makeApp`** (after `KeyRoutes.register`)

```swift
WebRoutes.register(router, store: keyStore, config: config)
```

- [ ] **Step 7: Run, confirm pass**

Run: `swift test`
Expected: all green, including new index test.

- [ ] **Step 8: Manual UI smoke**

Run with the test yaml from Task 2.8 and `open http://localhost:8080` in a browser. Verify:
- Title shows
- Install command visible
- Copy button responds
- Type filter changes both the command and visible rows
- Page is readable on a narrow window (<= 400px wide)

- [ ] **Step 9: Commit**

```bash
git add Sources Tests
git commit -m "feat: terminal-themed index page with copy + filter"
```

---

### Task 3.2: HTML escaping unit tests

**Files:**
- Modify: `Tests/AppTests/RouteTests.swift` (or new file `IndexViewTests.swift`)

- [ ] **Step 1: Create `Tests/AppTests/IndexViewTests.swift`**

```swift
import Testing
@testable import App

@Suite struct IndexViewTests {
    @Test func escapesHtmlInTitle() {
        var cfg = Config.testDefault
        cfg.title = "<script>alert(1)</script>"
        let html = IndexView.render(config: cfg, keys: [], lastRefresh: nil)
        #expect(!html.contains("<script>alert(1)</script>"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func escapesHtmlInComment() throws {
        let key = try SSHKey.parse("ssh-ed25519 AAAA <evil>", source: .manual)
        let html = IndexView.render(config: .testDefault, keys: [key], lastRefresh: nil)
        #expect(html.contains("&lt;evil&gt;"))
    }
}
```

- [ ] **Step 2: Run, confirm pass**

- [ ] **Step 3: Commit**

```bash
git add Tests
git commit -m "test: html escaping in IndexView"
```

---

## Phase 4 — Containerization

### Task 4.1: Dockerfile

**Files:**
- Create: `Dockerfile`
- Create: `.dockerignore`

- [ ] **Step 1: Write `.dockerignore`**

```
.build
.git
.github
.swiftpm
docs
Tests
config/keys.test.yaml
*.md
```

- [ ] **Step 2: Write multi-stage `Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1.6
FROM swift:6.0-jammy AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources/ Sources/
COPY Tests/ Tests/
RUN swift build -c release --static-swift-stdlib
RUN cp $(swift build -c release --show-bin-path)/App /app/App

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libxml2 \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 1000 sshportal && useradd -u 1000 -g sshportal -s /bin/false -m sshportal
WORKDIR /app
COPY --from=builder /app/App /app/App
USER sshportal
EXPOSE 8080
ENV HOST=0.0.0.0 PORT=8080 KEYS_FILE=/config/keys.yaml
ENTRYPOINT ["/app/App"]
```

- [ ] **Step 3: Build the image locally**

Run: `docker build -t sshportal:dev .`
Expected: image built. (If on macOS without Docker, skip — flag this in the commit message.)

- [ ] **Step 4: Run the image with example config**

```bash
docker run --rm -p 8080:8080 -v "$PWD/config/keys.example.yaml:/config/keys.yaml:ro" \
  -e BASE_URL=http://localhost:8080 -e TITLE=demo sshportal:dev &
sleep 3
curl -sf http://localhost:8080/health
docker stop $(docker ps -q --filter ancestor=sshportal:dev)
```
Expected: returns `{"status":"ok"...}`. The example yaml has placeholder usernames, so `/keys` may return only manual keys (or none) — that's fine.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile .dockerignore
git commit -m "build: multi-stage dockerfile, runs as non-root sshportal user"
```

---

### Task 4.2: Swift Container Plugin support

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add the plugin**

In `Package.swift` `dependencies`:
```swift
.package(url: "https://github.com/apple/swift-container-plugin.git", from: "1.0.0"),
```

(The plugin attaches automatically — no target wiring needed for command plugins. If `swift package plugin --list` does not show it, add an explicit `plugins:` to the `executableTarget`.)

- [ ] **Step 2: Try building a container image**

Run: `swift package --allow-network-connections all build-container-image --repository ghcr.io/murilxaraujo/sshportal --tag dev`
Expected: produces an OCI image. (If it fails — for example because of TUN networking on macOS — document in README that the Dockerfile path is preferred and skip this build.)

- [ ] **Step 3: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "build: add swift-container-plugin for OCI image builds"
```

---

### Task 4.3: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write CI workflow**

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    container: swift:6.0-jammy
    steps:
      - uses: actions/checkout@v4
      - run: swift package resolve
      - run: swift build
      - run: swift test
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: build and test on every PR via GitHub Actions"
```

---

### Task 4.4: GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Write release workflow**

```yaml
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
  packages: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest
      - uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
      - uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: publish multi-arch image to ghcr.io on tag push"
```

---

## Phase 5 — Polish & Release

### Task 5.1: Rate limiting middleware

**Files:**
- Create: `Sources/App/Services/RateLimiter.swift`
- Create: `Tests/AppTests/RateLimiterTests.swift`
- Modify: `Sources/App/ServerBuilder.swift`

- [ ] **Step 1: Failing test**

```swift
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
        #expect(await rl.allow(ip: "1.2.3.4") == false)
    }

    @Test func differentIpsHaveSeparateBuckets() async {
        let rl = TokenBucketRateLimiter(perMinute: 1, now: { Date(timeIntervalSince1970: 0) })
        #expect(await rl.allow(ip: "1.1.1.1"))
        #expect(await rl.allow(ip: "2.2.2.2"))
    }

    @Test func bucketRefillsOverTime() async {
        var t = Date(timeIntervalSince1970: 0)
        let rl = TokenBucketRateLimiter(perMinute: 1, now: { t })
        #expect(await rl.allow(ip: "x"))
        #expect(await rl.allow(ip: "x") == false)
        t = t.addingTimeInterval(60)
        #expect(await rl.allow(ip: "x"))
    }
}
```

- [ ] **Step 2: Implement `RateLimiter.swift`**

```swift
import Foundation
import Hummingbird

public actor TokenBucketRateLimiter {
    private struct Bucket { var tokens: Double; var lastRefill: Date }

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

public struct RateLimitMiddleware<Context: RequestContext>: RouterMiddleware {
    public let limiter: TokenBucketRateLimiter

    public func handle(_ input: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let ip = input.headers[.xForwardedFor]?.split(separator: ",").first.map(String.init) ?? "unknown"
        if await limiter.allow(ip: ip) {
            return try await next(input, context)
        }
        return Response(
            status: .tooManyRequests,
            headers: [.contentType: "text/plain"],
            body: ResponseBody(byteBuffer: .init(string: "rate limited\n"))
        )
    }
}
```

- [ ] **Step 3: Wire it in `ServerBuilder.makeApp`** (before route registration):

```swift
let limiter = TokenBucketRateLimiter(perMinute: 60)
router.middlewares.add(RateLimitMiddleware<BasicRequestContext>(limiter: limiter))
```

- [ ] **Step 4: Run tests, confirm pass**

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "feat: token-bucket rate limiter middleware (60 req/min/IP)"
```

---

### Task 5.2: install.sh helper script

**Files:**
- Create: `scripts/install.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# install.sh — append SSHPortal keys to ~/.ssh/authorized_keys without duplicates.
# Usage: curl -fsSL https://your-portal/install.sh | bash
#        curl -fsSL https://your-portal/install.sh | TYPE=ed25519 bash
set -euo pipefail

PORTAL="${PORTAL:-PORTAL_URL_PLACEHOLDER}"
TYPE="${TYPE:-}"

URL="$PORTAL/keys"
if [ -n "$TYPE" ]; then URL="$PORTAL/keys/$TYPE"; fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
TOUCH_AUTH="$HOME/.ssh/authorized_keys"
[ -f "$TOUCH_AUTH" ] || touch "$TOUCH_AUTH"
chmod 600 "$TOUCH_AUTH"

NEW="$(curl -fsSL "$URL")"
ADDED=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! grep -qxF "$line" "$TOUCH_AUTH"; then
    echo "$line" >> "$TOUCH_AUTH"
    ADDED=$((ADDED+1))
  fi
done <<< "$NEW"

echo "sshportal: added $ADDED key(s)"
```

(`PORTAL_URL_PLACEHOLDER` is replaced by the user — add a note in README.)

- [ ] **Step 2: Make it executable and shellcheck**

```bash
chmod +x scripts/install.sh
command -v shellcheck >/dev/null && shellcheck scripts/install.sh
```

- [ ] **Step 3: Smoke test against a running local server**

```bash
KEYS_FILE=config/keys.example.yaml swift run App &
sleep 2
PORTAL=http://localhost:8080 bash scripts/install.sh
grep -c '^ssh-' /tmp/.test-auth || true
kill %1
```
(Or run twice and confirm second run reports `added 0`.)

- [ ] **Step 4: Commit**

```bash
git add scripts/install.sh
git commit -m "feat: install.sh helper with idempotent dedupe"
```

---

### Task 5.3: README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace stub with full README** (see template below)

```markdown
# SSHPortal

Self-hosted SSH public key distribution portal. Visit a single URL, copy a one-liner, paste it on any server you control to authorize your keys.

## Quickstart

```bash
docker run -d --name sshportal \
  -p 8080:8080 \
  -v "$PWD/keys.yaml:/config/keys.yaml:ro" \
  -e BASE_URL=https://keys.example.com \
  -e TITLE=yourhandle \
  ghcr.io/murilxaraujo/sshportal:latest
```

Open `http://localhost:8080`. On a server, run:

```bash
curl -fs https://keys.example.com/keys >> ~/.ssh/authorized_keys
```

## Configuration

### `keys.yaml`

```yaml
title: yourhandle
sources:
  github:
    - your-github-username
  gitlab:
    - your-gitlab-username
  manual:
    - comment: Yubikey
      key: "sk-ecdsa-sha2-nistp256@openssh.com AAAA... user@yubikey"
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `HOST` | `0.0.0.0` | bind address |
| `BASE_URL` | `http://localhost:8080` | public URL shown in install command |
| `TITLE` | `sshportal` | UI heading |
| `KEYS_FILE` | `/config/keys.yaml` | YAML config path |
| `REFRESH_INTERVAL` | `3600` | seconds between remote refresh (0 = startup only) |
| `THEME_COLOR` | `#00FF41` | accent color (hex) |
| `LOG_LEVEL` | `info` | debug/info/warning/error |

## Endpoints

- `GET /` — HTML UI
- `GET /keys` — all keys, `text/plain`
- `GET /keys/:type` — filtered (`ed25519`, `rsa`, `ecdsa`, `ecdsa-sk`, `ed25519-sk`)
- `GET /health` — JSON health probe

## Security

Always serve over HTTPS in production. Without TLS, a MITM attacker can substitute keys in transit. Put SSHPortal behind nginx/Caddy/Traefik for TLS.

The container runs as a non-root `sshportal` user. The keys file should be mounted read-only.

## Development

```bash
swift run App
KEYS_FILE=config/keys.example.yaml swift run App
swift test
```

## License

MIT — see `LICENSE`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: full README with quickstart and configuration reference"
```

---

### Task 5.4: Tag v1.0.0

- [ ] **Step 1: Run all tests one more time**

Run: `swift test`
Expected: green.

- [ ] **Step 2: Build container image**

Run: `docker build -t sshportal:v1.0.0 .`
Expected: image builds successfully.

- [ ] **Step 3: Tag and push**

```bash
git tag v1.0.0 -m "v1.0.0"
git push origin main
git push origin v1.0.0
```

This triggers `release.yml`, which builds and pushes `ghcr.io/murilxaraujo/sshportal:1.0.0` and `:latest`.

- [ ] **Step 4: Verify the published image**

```bash
docker pull ghcr.io/murilxaraujo/sshportal:1.0.0
docker run --rm -p 8080:8080 -v "$PWD/config/keys.example.yaml:/config/keys.yaml:ro" ghcr.io/murilxaraujo/sshportal:1.0.0 &
sleep 3
curl -sf http://localhost:8080/health
docker stop $(docker ps -q --filter ancestor=ghcr.io/murilxaraujo/sshportal:1.0.0)
```

---

## Acceptance Criteria Coverage

| Criterion | Tasks |
|---|---|
| `docker run` starts the server | 4.1, 5.4 |
| `curl /keys >> authorized_keys` works | 1.4, 2.7 |
| GitHub + GitLab + manual merge | 2.5 |
| Dedupe by fingerprint | 2.1, 2.4 |
| Web UI with badges and copy | 3.1 |
| Type filter dropdown | 3.1 |
| Image on ghcr.io tagged | 4.4, 5.4 |
| Env vars all functional | 2.2, 2.8 |
| Non-root container | 4.1 |
| Unit tests for parsing/config/dedupe/filtering | 2.1, 2.2, 2.4, 2.7 |
| README quickstart + config | 5.3 |

## Self-Review Notes

- Spec coverage: every section 1–11 maps to one or more tasks above. Section 13 open questions resolved at top of this plan.
- No placeholders: every task contains the code, command, and expected output.
- Type consistency: `KeyStore.empty()`, `KeyStore.replaceAll`, `KeyStore.refreshOnce` are introduced in 1.3, 2.4, 2.6 and used consistently afterwards. `SSHKeyType` raw values match `/keys/:type` route in 2.7. `RemoteKeyFetcher` signature stays constant from 2.3 through 2.8.
