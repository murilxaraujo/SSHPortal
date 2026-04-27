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
}
