import Foundation

public enum IndexView {
    public static func render(config: Config, keys: [SSHKey], lastRefresh: Date?) -> String {
        let title = htmlEscape(config.title)
        let baseURL = trimTrailingSlash(config.baseURL)
        let primary = config.themeColor
        let installCmd = "curl -fs \(baseURL)/keys >> ~/.ssh/authorized_keys"
        let typeOptions = ([("all", "All")] + SSHKeyType.allCases.map { ($0.rawValue, $0.displayName) })
            .map { "<option value=\"\($0.0)\">\($0.1)</option>" }
            .joined()
        let keyRows = keys.map { keyRow($0) }.joined(separator: "\n")
        let lastRefreshStr = lastRefresh.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
        let css = StyleSheet.css(primary: primary)
        let svgFavicon = Favicon.svg(primary: primary)
        let escapedFavicon = percentEscape(svgFavicon)

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title) — sshportal</title>
        <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;utf8,\(escapedFavicon)">
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
        let truncated = String(k.fingerprint.prefix(36)) + (k.fingerprint.count > 36 ? "…" : "")
        let fp = htmlEscape(truncated)
        let sourceIcon: String
        switch k.source {
        case .github: sourceIcon = "GH"
        case .gitlab: sourceIcon = "GL"
        case .manual: sourceIcon = "··"
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
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#%")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func trimTrailingSlash(_ s: String) -> String {
        var out = s
        while out.hasSuffix("/") { out.removeLast() }
        return out
    }
}
