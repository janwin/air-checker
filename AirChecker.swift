import AppKit

struct Location {
    let name: String
    let apiURL: URL
    let mapURL: URL
}

let locations = [
    Location(
        name: "Family Village",
        apiURL: URL(string: "https://map-data.airgradient.com/map/api/v1/measurements/current/cluster?xmin=115.14936268329622&ymin=-8.620791280644355&xmax=115.15554785728456&ymax=-8.616930086427498&zoom=18&measure=pm25&excludeOutliers=true")!,
        mapURL: URL(string: "https://www.airgradient.com/map/?lat=-8.61836&long=115.15169&zoom=17")!
    ),
    Location(
        name: "Green School",
        apiURL: URL(string: "https://map-data.airgradient.com/map/api/v1/measurements/current/cluster?xmin=115.20525455474855&ymin=-8.570645857912623&xmax=115.21762490272523&ymax=-8.56292240879587&zoom=17&measure=pm25&excludeOutliers=true")!,
        mapURL: URL(string: "https://www.airgradient.com/map/?lat=-8.56775&long=115.21265&zoom=17")!
    ),
]
let selectedKey = "selectedLocation"
let refreshInterval: TimeInterval = 60

struct Response: Decodable {
    struct Sensor: Decodable {
        let value: Double?
    }
    let data: [Sensor]
}

// PM2.5 thresholds: green 0-10, yellow 10-34, orange 35-50, red 50-74, dark red >=75
func colors(for pm25: Double) -> (background: NSColor, text: NSColor) {
    switch pm25 {
    case ..<10: return (NSColor(red: 0.20, green: 0.70, blue: 0.30, alpha: 1), .white)
    case ..<35: return (NSColor(red: 1.00, green: 0.85, blue: 0.10, alpha: 1), .black)
    case ..<50: return (NSColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1), .black)
    case ..<75: return (NSColor(red: 0.90, green: 0.10, blue: 0.10, alpha: 1), .white)
    default:    return (NSColor(red: 0.50, green: 0.00, blue: 0.10, alpha: 1), .white)
    }
}

func badge(text: String, background: NSColor, foreground: NSColor) -> NSImage {
    let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
    let textSize = (text as NSString).size(withAttributes: attrs)
    let size = NSSize(width: max(textSize.width + 12, 24), height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        background.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        let origin = NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2)
        (text as NSString).draw(at: origin, withAttributes: attrs)
        return true
    }
    image.isTemplate = false
    return image
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var locationItems: [NSMenuItem] = []
    let updatedItem = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
    var values: [Double?] = Array(repeating: nil, count: locations.count)
    var selected = min(UserDefaults.standard.integer(forKey: selectedKey), locations.count - 1)
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        for (index, location) in locations.enumerated() {
            let item = NSMenuItem(title: location.name, action: #selector(select(_:)), keyEquivalent: "")
            item.tag = index
            locationItems.append(item)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(updatedItem)
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Open AirGradient Map", action: #selector(openMap), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        render()

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in self?.refresh() }
    }

    @objc func select(_ sender: NSMenuItem) {
        selected = sender.tag
        UserDefaults.standard.set(selected, forKey: selectedKey)
        render()
    }

    @objc func openMap() {
        NSWorkspace.shared.open(locations[selected].mapURL)
    }

    @objc func refresh() {
        let group = DispatchGroup()
        var results = values
        var failures: [String] = []
        for (index, location) in locations.enumerated() {
            var request = URLRequest(url: location.apiURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            group.enter()
            URLSession.shared.dataTask(with: request) { data, _, _ in
                let value = data.flatMap { try? JSONDecoder().decode(Response.self, from: $0) }?.data.first?.value
                DispatchQueue.main.async {
                    results[index] = value
                    if value == nil { failures.append(location.name) }
                    group.leave()
                }
            }.resume()
        }
        group.notify(queue: .main) {
            self.values = results
            let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            self.updatedItem.title = failures.isEmpty
                ? "Updated \(time)"
                : "Updated \(time) — failed: \(failures.joined(separator: ", "))"
            self.render()
        }
    }

    func render() {
        for (index, item) in locationItems.enumerated() {
            item.state = index == selected ? .on : .off
            if let value = values[index] {
                let (bg, fg) = colors(for: value)
                item.image = badge(text: String(Int(value.rounded())), background: bg, foreground: fg)
                item.title = "\(locations[index].name) — \(Int(value.rounded())) µg/m³"
            } else {
                item.image = badge(text: "?", background: .gray, foreground: .white)
                item.title = locations[index].name
            }
        }
        let location = locations[selected]
        if let value = values[selected] {
            let (bg, fg) = colors(for: value)
            statusItem.button?.image = badge(text: String(Int(value.rounded())), background: bg, foreground: fg)
            statusItem.button?.toolTip = "\(location.name) PM2.5: \(value) µg/m³"
        } else {
            statusItem.button?.image = badge(text: "?", background: .gray, foreground: .white)
            statusItem.button?.toolTip = "\(location.name): no data"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
