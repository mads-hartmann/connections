import SwiftUI
import WebKit

/// A SwiftUI wrapper around WKWebView for displaying web content.
struct WebContentView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Enable reader-friendly appearance
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if webView.url != url {
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow the initial load, but open clicked links in the system browser
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject reader-friendly CSS after page loads
            let css = """
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                max-width: 720px;
                margin: 20px auto;
                padding: 0 16px;
                line-height: 1.6;
                color: #1d1d1f;
                background: transparent;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #f5f5f7; }
                a { color: #6cb4ee; }
            }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            pre { overflow-x: auto; padding: 12px; border-radius: 6px; background: rgba(128,128,128,0.1); }
            code { font-size: 0.9em; }
            nav, footer, .ads, .advertisement, .social-share, .comments, .related-posts, .sidebar {
                display: none !important;
            }
            """
            let js = """
            var style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }
    }
}
