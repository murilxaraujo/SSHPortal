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
