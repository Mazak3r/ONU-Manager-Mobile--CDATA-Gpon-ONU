# ONT-Manager--CDATATEC-GPON-Router

## Router Dashboard & Automation (Flutter)

A modern, mobile-first Flutter application designed to replace the clunky, default web interface of CDATATEC GPON routers (tested on Model FD514GD-R460).

Instead of scraping a WebView or relying on the router's mobile site, this app reverse-engineers the router's internal API to provide a fast, native, and beautiful user experience.

Key Features:

- Zero-WebView Architecture: Pure Dart HTTP client for lightning-fast responses.

- Live Dashboard: Real-time animated download/upload speeds and a live preview of connected devices.

- Optical Health (PON): At-a-glance metrics for RX Power, TX Power, and Module Temperature with color-coded health indicators.

- Device Management: View all connected devices, their IP/MAC addresses, and Wi-Fi link speeds.

- Wi-Fi Control: View enabled SSIDs and securely update Wi-Fi names and passwords.

- Remote Actions: Send a reboot command directly from the app.

- Auto-Healing Auth: Handles MD5 password hashing, token generation, and silent auto-relogins if the router token expires.

Tech Stack:

- Flutter & Dart

- http (Network requests)

- crypto (MD5 password hashing)

- shared_preferences (Saving credentials for auto-connect)



