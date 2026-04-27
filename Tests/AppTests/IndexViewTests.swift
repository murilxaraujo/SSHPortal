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
        #expect(!html.contains("<evil>"))
    }
}
