<p align="center">
  <img src="branding/logo-512.png" width="128" alt="Hemera app icon">
</p>

<h1 align="center">Hemera</h1>

<p align="center">An open-source Home Assistant client for iOS, built with SwiftUI.</p>

## Features

**Control** — Lights with brightness, color temperature, and color picking. Covers with position control and open/close/stop. Climate with HVAC modes, target temperature, and fan speed. Switches, buttons, scenes, and automations.

**Dashboard** — Customizable tile grid with drag-and-drop reordering. Curated Home tab for your favorite entities and area-based browsing for everything else. Real-time state sync over WebSocket.

**Display** — Stay-awake mode with configurable inactivity dimming. Full-screen clock for wall-mounted or bedside use. Configurable 12/24-hour time format.

**Try before you connect** — Built-in demo mode with realistic entities across multiple rooms. No Home Assistant server required.

## Local Development Setup

1. Clone the repository
2. Copy the signing config template:
   ```bash
   cp Config/Local.xcconfig.template Config/Local.xcconfig
   ```
3. Edit `Config/Local.xcconfig` and set your Apple Development Team ID:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
   ```
   To find your Team ID, run:
   ```bash
   security find-identity -v -p codesigning
   ```
   The 10-character alphanumeric ID in parentheses at the end of each line is your Team ID. You can also find it in Xcode under Settings > Accounts.
4. Open `Hemera.xcodeproj` in Xcode and build

## License

MIT - see [LICENSE](LICENSE) for details.
