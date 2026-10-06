# AirChecker

A small macOS menu bar app that shows the current PM2.5 air quality (µg/m³) from [AirGradient](https://www.airgradient.com/map/) sensors as a number on a colored badge.

| Color    | PM2.5 (µg/m³) |
|----------|---------------|
| Green    | 0 – 9         |
| Yellow   | 10 – 34       |
| Orange   | 35 – 49       |
| Red      | 50 – 74       |
| Dark red | 75+           |

Values refresh every 60 seconds. Click the badge to see all sensors; click a sensor to show it in the menu bar (the choice is remembered). A grey `?` means the last fetch failed.

## Install

Requirements: macOS 13+ and the Swift compiler (included with Xcode or the Command Line Tools — run `xcode-select --install` if `swiftc` is missing).

```sh
./build.sh                       # builds AirChecker.app in this folder
mv AirChecker.app /Applications/ # optional, but recommended
open /Applications/AirChecker.app
```

The app has no Dock icon — look for the badge in the menu bar. Quit it from its menu.

## Autostart on login

1. Open **System Settings → General → Login Items & Extensions**.
2. Under **Open at Login**, click **+**.
3. Select `AirChecker.app` (in `/Applications` if you moved it there) and click **Open**.

To stop autostarting, select it in that list and click **−**.

## Add more sensors

1. Open the [AirGradient map](https://www.airgradient.com/map/), zoom in on the sensor you want, and open your browser's developer tools (Network tab).
2. Find the request to `map-data.airgradient.com/map/api/v1/measurements/current/cluster?...&measure=pm25...` and copy its URL. Make sure the bounding box (`xmin`/`ymin`/`xmax`/`ymax`) contains only the one sensor — the app uses the first result.
3. Check it returns the sensor you expect:
   ```sh
   curl -s '<the URL>'
   ```
4. Add an entry to the `locations` list at the top of `AirChecker.swift`:
   ```swift
   Location(
       name: "My Sensor",
       apiURL: URL(string: "https://map-data.airgradient.com/map/api/v1/measurements/current/cluster?xmin=...&ymin=...&xmax=...&ymax=...&zoom=17&measure=pm25&excludeOutliers=true")!,
       mapURL: URL(string: "https://www.airgradient.com/map/?lat=<latitude>&long=<longitude>&zoom=17")!
   ),
   ```
   `name` is what the menu shows; `mapURL` is opened by "Open AirGradient Map" (use the `latitude`/`longitude` from the curl response).
5. Rebuild and restart:
   ```sh
   pkill -x AirChecker; ./build.sh && open AirChecker.app
   ```
   If you installed to `/Applications`, move the new `AirChecker.app` there again (replacing the old one).

The color thresholds live in `colors(for:)` and the refresh interval in `refreshInterval`, both in `AirChecker.swift`.
