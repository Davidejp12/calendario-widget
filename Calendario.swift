// Widget desktop: calendario da un database Notion (proprietà Name + Date).
// Finestra senza bordi incollata allo sfondo, sotto tutte le altre finestre.
// Si trascina dalla barra in alto, si ridimensiona dall'angolo in basso a destra;
// posizione e grandezza vengono ricordate.

import Cocoa
import WebKit

// Cartella con widget.html, cache.json, token.txt, database_id.txt: accanto all'eseguibile o accanto a Calendario.app
let dir: URL = {
    let bundle = Bundle.main.bundleURL
    if bundle.pathExtension == "app" { return bundle.deletingLastPathComponent() }
    return URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
}()
let cacheURL = dir.appendingPathComponent("cache.json")
let tokenURL = dir.appendingPathComponent("token.txt")
let settingsURL = dir.appendingPathComponent("settings.json")
let databaseURL = dir.appendingPathComponent("database_id.txt")
let refreshEvery: TimeInterval = 5 * 60
let defaultSize = NSSize(width: 760, height: 480)
let minSize = NSSize(width: 420, height: 300)

// Senza bordi una finestra non riceve la tastiera: serve per scrivere nel modulo eventi.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class DragWebView: WKWebView {
    // Barra del titolo (44px, esclusi i pulsanti a destra) = trascina; angolo in basso a destra = ridimensiona.
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let fromTop = isFlipped ? p.y : bounds.height - p.y
        let fromBottom = bounds.height - fromTop
        if fromBottom < 22 && p.x > bounds.width - 22 {
            resize(from: event)
        } else if fromTop < 44 && p.x < bounds.width - 180 {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func resize(from event: NSEvent) {
        guard let w = window else { return }
        let start = NSEvent.mouseLocation, frame = w.frame
        while let e = w.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), e.type != .leftMouseUp {
            let p = NSEvent.mouseLocation
            var f = frame
            f.size.width = max(minSize.width, frame.width + p.x - start.x)
            f.size.height = max(minSize.height, frame.height + start.y - p.y)
            f.origin.y = frame.maxY - f.height
            w.setFrame(f, display: true)
        }
    }
}

final class App: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: KeyWindow!
    var web: DragWebView!

    func applicationDidFinishLaunching(_ n: Notification) {
        let screen = NSScreen.main!.visibleFrame
        let origin = NSPoint(x: screen.maxX - defaultSize.width - 30, y: screen.maxY - defaultSize.height - 30)
        window = KeyWindow(contentRect: NSRect(origin: origin, size: defaultSize),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = minSize
        window.setFrameAutosaveName("CalendarioNotion")

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: window.frame.size))
        blur.material = .hudWindow
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true
        blur.autoresizingMask = [.width, .height]

        // il colore di fondo lo disegna widget.html, così il tema si cambia da lì
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "app")
        web = DragWebView(frame: blur.bounds, configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        blur.addSubview(web)

        window.contentView = blur
        window.orderFront(nil)
        web.loadFileURL(dir.appendingPathComponent("widget.html"), allowingReadAccessTo: dir)

        Timer.scheduledTimer(withTimeInterval: refreshEvery, repeats: true) { _ in self.refresh() }
    }

    func webView(_ w: WKWebView, didFinish nav: WKNavigation!) {
        if let s = try? Data(contentsOf: settingsURL) { call("applySettings", s) }
        if let c = try? Data(contentsOf: cacheURL) { call("setData", c) }
        refresh()
    }

    // Messaggi da widget.html: {action: "open" | "settings" | "size" | "focus" | "create", ...}
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let msg = m.body as? [String: Any], let action = msg["action"] as? String else { return }
        switch action {
        case "open":
            if let s = msg["url"] as? String, let url = URL(string: s) { NSWorkspace.shared.open(url) }
        case "settings":
            if let s = msg["settings"], let data = try? JSONSerialization.data(withJSONObject: s, options: [.prettyPrinted]) {
                try? data.write(to: settingsURL)
            }
        case "size":
            guard let w = msg["w"] as? Double, let h = msg["h"] as? Double else { return }
            var f = window.frame
            f.origin.y = f.maxY - h
            f.size = NSSize(width: w, height: h)
            window.setFrame(f, display: true, animate: true)
        case "focus":
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        case "create":
            createEvent(title: msg["title"] as? String ?? "", start: msg["start"] as? String ?? "", end: msg["end"] as? String)
        default: break
        }
    }

    func call(_ fn: String, _ json: Data) {
        guard let s = String(data: json, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.\(fn)(\(s))")
    }

    func callSaved(_ ok: Bool, _ message: String) {
        let arg = (try? JSONSerialization.data(withJSONObject: [message], options: [.fragmentsAllowed]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        DispatchQueue.main.async { self.web.evaluateJavaScript("window.onSaved(\(ok), \(arg)[0])") }
    }

    // MARK: Notion

    func readFile(_ url: URL) -> String? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
    func token() -> String? { readFile(tokenURL) }
    // accetta l'ID nudo o il link completo del database Notion
    func databaseID() -> String? {
        guard let raw = readFile(databaseURL) else { return nil }
        let hex = raw.split(separator: "?")[0].replacingOccurrences(of: "-", with: "")
        return hex.count >= 32 ? String(hex.suffix(32)) : nil
    }

    func request(_ path: String, body: [String: Any], token: String) -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.notion.com/v1/\(path)")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    func refresh() {
        guard let token = token(), let db = databaseID() else { return }
        fetch(token: token, database: db, cursor: nil, acc: [])
    }

    func fetch(token: String, database: String, cursor: String?, acc: [[String: Any]]) {
        var body: [String: Any] = ["page_size": 100,
                                   "filter": ["property": "Date", "date": ["is_not_empty": true]]]
        if let cursor { body["start_cursor"] = cursor }

        URLSession.shared.dataTask(with: request("databases/\(database)/query", body: body, token: token)) { data, resp, _ in
            guard let data, (resp as? HTTPURLResponse)?.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = obj["results"] as? [[String: Any]] else {
                DispatchQueue.main.async { self.markOffline() }
                return
            }
            var events = acc
            for page in results {
                guard let props = page["properties"] as? [String: Any],
                      let date = (props["Date"] as? [String: Any])?["date"] as? [String: Any],
                      let start = date["start"] as? String else { continue }
                let title = ((props["Name"] as? [String: Any])?["title"] as? [[String: Any]] ?? [])
                    .compactMap { $0["plain_text"] as? String }.joined()
                events.append(["title": title.isEmpty ? "Senza titolo" : title,
                               "start": start,
                               "end": date["end"] as? String ?? NSNull(),
                               "url": page["url"] as? String ?? ""])
            }
            if obj["has_more"] as? Bool == true, let next = obj["next_cursor"] as? String {
                self.fetch(token: token, database: database, cursor: next, acc: events)
                return
            }
            let out: [String: Any] = ["updated": ISO8601DateFormatter().string(from: Date()),
                                      "source": "notion", "events": events]
            guard let json = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted]) else { return }
            try? json.write(to: cacheURL)
            DispatchQueue.main.async { self.call("setData", json) }
        }.resume()
    }

    func createEvent(title: String, start: String, end: String?) {
        guard let token = token() else { return callSaved(false, "Manca il token Notion (token.txt)") }
        guard let databaseID = databaseID() else { return callSaved(false, "Manca l'ID del database (database_id.txt)") }
        var date: [String: Any] = ["start": start]
        if let end, !end.isEmpty { date["end"] = end }
        let body: [String: Any] = [
            "parent": ["database_id": databaseID],
            "properties": ["Name": ["title": [["text": ["content": title]]]],
                           "Date": ["date": date]],
        ]
        URLSession.shared.dataTask(with: request("pages", body: body, token: token)) { data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                self.callSaved(true, "Salvato su Notion")
                self.refresh()
            } else {
                let detail = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["message"] as? String
                self.callSaved(false, detail ?? "Notion non risponde")
            }
        }.resume()
    }

    func markOffline() {
        web.evaluateJavaScript("data.source = 'error'; render()")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // niente icona nel Dock
let delegate = App()
app.delegate = delegate
app.run()
