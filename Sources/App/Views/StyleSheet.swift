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
        code { color: var(--fg); }
        .install-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 12px; }
        .install-toolbar label { color: var(--muted); font-size: 12px; display: flex; align-items: center; gap: 8px; }
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
        footer { margin-top: 24px; display: flex; justify-content: space-between; color: var(--muted); font-size: 12px; gap: 12px; flex-wrap: wrap; }
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
        document.querySelectorAll('.key-row').forEach(function(r) {
          r.style.display = (t === 'all' || r.dataset.type === t) ? '' : 'none';
        });
      }
      sel.addEventListener('change', update);
      btn.addEventListener('click', async function() {
        const text = cmd.textContent;
        try {
          await navigator.clipboard.writeText(text);
        } catch (_e) {
          const r = document.createRange();
          r.selectNodeContents(cmd);
          const s = window.getSelection();
          s.removeAllRanges();
          s.addRange(r);
        }
        btn.classList.add('copied');
        const orig = btn.textContent;
        btn.textContent = 'Copied ✓';
        setTimeout(function(){ btn.textContent = orig; btn.classList.remove('copied'); }, 2000);
      });
    })();
    """#
}
