# PGW Receipts iOS App

## Setup in Xcode

1. Open Xcode → **Create New Project**
2. Choose **iOS → App**
3. Settings:
   - Product Name: `PGWReceipts`
   - Team: (your Apple ID)
   - Bundle Identifier: `com.nexalworks.pgwreceipts`
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save it anywhere (Desktop is fine)

## Add the Swift files

In Xcode's left sidebar (Project Navigator):
- Delete the auto-generated `ContentView.swift`
- Right-click the `PGWReceipts` folder → **Add Files to "PGWReceipts"**
- Select all `.swift` files from `~/aiprojects/pgw/PGWReceipts/`

## Add camera & photo permissions

Click the project name in the sidebar → select the **PGWReceipts** target → **Info** tab.
Add these keys:
- `Privacy - Photo Library Usage Description` → `"Used to select receipt photos for upload"`
- `Privacy - Camera Usage Description` → `"Used to photograph receipts"`

## Run on your iPhone

1. Connect iPhone via USB
2. Select your iPhone in the top device picker
3. Press **Run** (▶)
4. On first run, go to iPhone Settings → General → VPN & Device Management → trust your developer certificate

## The app connects to
`https://app.nexalworks.com` — same login as the web dashboard.
