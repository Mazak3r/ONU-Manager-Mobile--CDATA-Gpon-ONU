<div align="center">

# 📱 ONU Manager Mobile
**A sleek, native Flutter dashboard for CDATATEC GPON Routers.**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=for-the-badge)](/)

*Ditch the clunky web interface. Monitor your fiber connection, manage devices, and control your router with a premium, native mobile experience.*

</div>

---

## ✨ Features

*   🚀 **Zero-WebView Architecture:** Lightning-fast performance using direct, pure Dart HTTP API calls.
*   📊 **Live Traffic Dashboard:** Beautifully animated real-time download/upload speeds.
*   🟢 **Optical Health (PON):** Instantly view RX Power, TX Power, and Temperature with color-coded health indicators.
*   📱 **Connected Devices:** See exactly who is on your network, including their hostname, IP, MAC address, and Wi-Fi link speed.
*   📡 **Wi-Fi Management:** View active SSIDs and seamlessly update Wi-Fi names and passwords.
*   🔄 **Remote Control:** Send a reboot command directly from the app.
*   🔐 **Auto-Healing Auth:** Automatically handles MD5 password hashing and silently refreshes expired session tokens.
*   💾 **Remember Me:** Saves your credentials securely so you auto-connect every time you open the app.

---

## 🎨 Design
Built with a modern, calming UI inspired by premium lifestyle apps. Features soft gradients, rounded glass-morphism elements, and fluid animations.

*(Tested on: CDATATEC FD514GD-R460 running Firmware V3.2.14)*

---

## 🛠️ Tech Stack
*   **Framework:** [Flutter](https://flutter.dev)
*   **Language:** [Dart](https://dart.dev)
*   **Networking:** `http` package
*   **Security:** `crypto` (for MD5 hashing)
*   **Storage:** `shared_preferences` (for auto-login)

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK installed on your machine.
*   Android Studio or Xcode.
*   Your phone must be connected to the router's Wi-Fi network (default: `192.168.101.1`).

### Installation
1. Clone the repository:
   ```bash
   git clone git@github.com:Mazak3r/ONU-Manager-Mobile--CDATA-Gpon-ONU.git
