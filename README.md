# ⚡ Roshan Alert (روشن الرٹ)

> A modern, real-time utility outage tracking & instant area notification system for Electricity & Gas load shedding in Pakistan. Built with Flutter, Firebase, and Node.js.

---

## 🌟 Key Features

- 🚨 **Real-Time Outage Alerts**: Instant crowd-sourced outage reporting and area verification.
- 🔔 **Closed-App Lock-Screen Push Notifications**: High-priority real-time notifications delivered to devices via Google FCM even when the app is completely closed or killed.
- 📅 **Custom Load Shedding Schedules**: Personal daily schedule manager with offline cache and cross-device account sync.
- 🎨 **Sleek & Adaptive Design System**: Supports seamless Dark and Light modes with custom HSL color palettes and micro-animations.
- 📍 **Area-Scoped Notification Scoping**: Device topic subscriptions (`ra_province_city_area_utility`) ensure users only receive alerts relevant to their exact neighborhood.
- 🔒 **Privacy & Security**: Zero sensitive keys committed; `.gitignore` protected with environment variable support for cloud deployment.

---

## 🏗️ Architecture & Technology Stack

### **1. Client Application (Flutter)**
- **Framework**: Flutter SDK (Dart 3.x)
- **State & Data**: `ValueNotifier`, `SharedPreferences` (Local Cache), `Cloud Firestore` (Cloud DB)
- **Auth**: `Firebase Auth` (Email/Password with email verification)
- **Local Notifications**: `flutter_local_notifications`
- **Push Messaging**: `firebase_messaging` (FCM Topic Subscriptions)

### **2. Notification Server (Node.js)**
- **Runtime**: Node.js v18+
- **Framework**: Express.js
- **Firebase Admin SDK**: `firebase-admin` (Real-time Firestore listener + FCM high-priority topic dispatch)

---

## 🚀 Quick Start Guide

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.12+)
- [Node.js](https://nodejs.org/) (v18+)
- Firebase Project configured (`roshan-alert`)

---

### 1. Flutter App Setup

```bash
# Clone repository
git clone <YOUR-REPO-URL>
cd roshan-alert

# Get Flutter dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

To build a release APK:
```bash
flutter build apk --release
```

---

### 2. Standalone FCM Push Notification Server Setup

```bash
# Navigate to server directory
cd server

# Install dependencies
npm install

# Option A: Place serviceAccountKey.json inside server/ directory
# Option B: Set FIREBASE_SERVICE_ACCOUNT environment variable

# Start server
node index.js
```

---

## ☁️ 24/7 Free Cloud Deployment (Render.com)

1. Connect your repository to **Render.com** (Free Web Service).
2. Set **Root Directory** to `server`.
3. Set **Build Command**: `npm install`
4. Set **Start Command**: `node index.js`
5. In **Environment Variables**, add:
   - `FIREBASE_SERVICE_ACCOUNT`: *Paste contents of `serviceAccountKey.json`*

---

## 🛡️ Security Note

All secret keys (`serviceAccountKey.json`, credentials) are strictly listed in `.gitignore` and will never be committed to Git or pushed to GitHub repositories.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.
