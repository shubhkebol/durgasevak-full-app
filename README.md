# 🚩 Durgasevak (दुर्गसेवक)
> **किल्ले संवर्धन व संस्था व्यवस्थापन ॲप्लिकेशन (Fort Conservation & Organization Management System)**

Durgasevak is a secure, offline-first mobile application designed specifically for fort conservation committees, historical preservation groups, and social organizations (*दुर्गसंवर्धन संस्था / मंडळ*). 

The app streamlines member records, fort expedition (*मोहीम*) attendance, donation collections with automated WhatsApp receipts, expense tracking, and financial transparency reports.

---

## 🎯 Purpose of the Application

Fort conservation organizations face unique operational challenges:
1. **Remote Expeditions**: Work takes place on forts and remote mountains with zero internet connectivity.
2. **Financial Accountability**: Accurate records of public donations and fort restoration expenditures must be transparent and verifiable.
3. **Receipting & Reminders**: Sending immediate donation receipts and periodic reminder messages to contributing members (*मावळे*).
4. **Decentralized Team Viewing**: Allowing committee members and viewers across various locations to view up-to-date data without risk of data tampering or credential leaks.

Durgasevak solves these challenges with an **offline-first local database (SQLite)** coupled with an **automated Google Drive cloud sync architecture**.

---

## 🌟 Key Features

### 1. 👥 Member Management (मावळे व सदस्य)
- Comprehensive directory of active and inactive members.
- Classification by roles, committee responsibilities, blood groups, and locations.
- Direct calling and WhatsApp integration.

### 2. 🏰 Mohim & Attendance (मोहीम उपस्थिती)
- Schedule and track fort conservation campaigns (*मोहीम*).
- Mark attendance for participating volunteers directly at the site without an internet connection.

### 3. 💰 Donation Tracking (देणगी नोंद)
- Record donations with donor name, amount, date, payment mode (Cash/UPI/Bank), and receipt numbers.
- **WhatsApp Instant Receipt**: Generate pre-formatted, polite Marathi receipt messages and share them to donors with a single tap.
- **Missed Donations Tracker**: Identify members who pledged or missed their periodic contributions and send polite reminder follow-ups on WhatsApp.

### 4. 🧾 Expense Tracking (खर्च नोंद)
- Track all expenditures with category tags (Travel, Food, Equipment, Restoration Material, Miscellaneous).
- Real-time balance calculations on the main Dashboard.

### 5. 📊 Reports & Financial Transparency (हिशोब व अहवाल)
- Summary statistics of income vs. expenses.
- Periodic breakdowns and downloadable audit reports.
- Read-only transparency view for all registered viewers.

### 6. 🔄 Google Drive Master Backup & Auto-Sync
- **Admin Upload on Pull-to-Refresh**: When the Admin swipes down on the dashboard, the app automatically uploads the latest database to the official Google Drive folder with **zero data loss**.
- **Viewer Download on Pull-to-Refresh**: When a Viewer swipes down on the dashboard, the app instantly pulls and restores the latest master database from Google Drive.
- **Zero Password Sharing**: Admin uses the official organization Gmail, then grants "Reader" permissions to viewers' Gmail accounts via Google Drive API. Viewers sign in with their own Gmails.
- **Local File Sharing**: Backup `.db` files can also be directly exported and imported via WhatsApp or email.

### 7. 📞 Official Admin Contact System
- The login screen provides a quick shortcut for new or prospective members to contact verified committee admins (**Aniket Patil** & **Nitesh Juikar**) via WhatsApp.
- Viewers needing Google Drive permission can send a pre-filled request to admins directly through WhatsApp.

---

## 🏗️ System Architecture

```
                    ┌─────────────────────────┐
                    │      Admin Device       │
                    │ (Full Read/Write/Edit)  │
                    └───────────┬─────────────┘
                                │
                      Pull-Down / Auto-Upload
                                │
                                ▼
               ┌───────────────────────────────┐
               │    Official Google Drive      │
               │   Folder: 'Durgasevak'        │
               │ File: 'durgasevak_backup.db'  │
               └───────────────┬───────────────┘
                               │
                     Pull-Down / Auto-Fetch
                               │
                               ▼
                    ┌─────────────────────────┐
                    │     Viewer Devices      │
                    │   (Read-Only Access)    │
                    └─────────────────────────┘
```

- **Local Storage**: SQLite (`sqflite`) for lightning-fast offline operations.
- **Framework**: Flutter (Dart) with native Material 3 design and Marathi Mukta typography.
- **Cloud Provider**: Google Drive API v3 via Google Identity Services (`google_sign_in`).
- **Package ID**: `com.durgasevak.app`

---

## 📱 User Roles

| Role | Access Level | Description |
|---|---|---|
| **Admin (`Admin`)** | Read / Write / Master Sync | Can add/edit members, donations, expenses, and upload master backups to Google Drive. |
| **Viewer (`Durgasevak`)** | Read-Only | Can view statistics, reports, and search records; pulls updates from Google Drive. |

---

## 🛠️ Build & Installation

### Prerequisites
- Flutter SDK `^3.13.2` or later
- Android SDK with Java 17+
- Android Keystore (Debug or Release)

### Steps to Build

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shubhkebol/durgasevak-full-app.git
   cd durgasevak-full-app/mobile
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Build Universal Release APK:**
   ```bash
   flutter build apk --release
   ```
   *Output file will be at: `build/app/outputs/flutter-apk/app-release.apk`*

4. **Build Split-per-ABI APKs (Smaller file size for modern phones):**
   ```bash
   flutter build apk --split-per-abi
   ```

---

## ⚙️ Google Cloud Configuration (Google Drive Sync)

To configure Google Drive backup in Google Cloud Console (`console.cloud.google.com`):
1. Enable **Google Drive API**.
2. Configure **OAuth Consent Screen** (User Type: External, Scopes: `.../auth/drive.file`, `.../auth/drive.readonly`).
3. Add Admin and Viewer test emails under **Audience ➔ Test Users**.
4. Create **Android OAuth Client ID**:
   - Package name: `com.durgasevak.app`
   - Debug SHA-1: `77:6A:46:27:4F:BB:CF:19:BB:B1:9C:B1:26:BD:EC:A9:11:C8:51:58`
5. Create **Web Application OAuth Client ID** and set in `GoogleDriveService._webClientId`.

---

## 📄 License & Attribution
Developed with reverence for the heritage of Chhatrapati Shivaji Maharaj and the tireless volunteers (*मावळे*) dedicated to fort conservation.
