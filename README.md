# Shelfie - Phase 1 Implementation

Phase 1 of the Shelfie read/watch later system is now complete! This implementation includes:

## ✅ What's Included

### 🗄️ Database (Supabase)
- Complete PostgreSQL schema with items, users, tags, and events tables
- Triggers for automatic timestamp updates and status management
- Indexes for performance
- Views for easy data access

### 🔧 Backend (Supabase Edge Functions)
- `save-url` Edge Function for processing URLs and extracting metadata
- YouTube video detection and thumbnail extraction
- HTML metadata parsing (title, description, Open Graph images)
- Deduplication logic
- Error handling and CORS support

### 🌐 Browser Extension (Chrome/Edge)
- Manifest V3 compatible
- Right-click context menu "Save to Read/Watch Later"
- Configuration popup for Supabase credentials
- Offline queue for failed saves
- Visual feedback and notifications

### 📱 Flutter App (Windows Desktop + Android)
- Material 3 design with light/dark theme support
- Three main tabs: Reading, Viewing, Archive
- Item cards with thumbnails, titles, and metadata
- Mark as read/watched functionality
- Manual URL addition
- Pull-to-refresh and error handling
- State management with Riverpod

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1+)
- Supabase account
- Chrome or Edge browser for extension
- Supabase CLI (for Edge Function deployment)

### 1. Setup Supabase Backend

1. **Install Supabase CLI** (choose one method):
   
   **Option A: Using Chocolatey (Windows - recommended)**
   ```bash
   choco install supabase
   ```
   
   **Option B: Using Scoop (Windows)**
   ```bash
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   scoop install supabase
   ```
   
   **Option C: Direct download (easiest)**
   - Go to [GitHub releases](https://github.com/supabase/cli/releases)
   - Download `supabase_windows_amd64.exe`
   - Rename to `supabase.exe` and add to your PATH
   
   **Option D: Use npx (no global install)**
   ```bash
   npx supabase login
   npx supabase functions deploy save-url
   ```

2. Create a new Supabase project at [supabase.com](https://supabase.com)

3. Run the database migration:
   ```sql
   -- Copy and run the contents of backend/supabase/migrations/20250813000001_initial_schema.sql
   -- in your Supabase SQL editor
   ```

4. Deploy the Edge Function:
   ```bash
   cd backend/supabase
   supabase login
   supabase functions deploy save-url
   ```
   
   **Alternative with npx (if CLI not globally installed):**
   ```bash
   cd backend/supabase
   npx supabase login
   npx supabase functions deploy save-url
   ```
   
   **Note**: When prompted, select your Shelfie project from the list.
   
   **Alternative: Manual Edge Function Setup (No CLI needed)**
   If you can't install the CLI, follow the steps in `SETUP-NO-CLI.md`:
   - Go to your Supabase project dashboard
   - Navigate to Edge Functions
   - Create a new function called `save-url`
   - Copy the contents of `backend/supabase/functions/save-url/index.ts`

4. Configure CORS in your Supabase project:
   - Go to Authentication > Settings
   - Add your domain and `chrome-extension://*` to allowed origins

### 2. Setup Browser Extension

1. Open Chrome/Edge and go to Extensions page
2. Enable "Developer mode"
3. Click "Load unpacked" and select the `browser-extension` folder
4. Click the extension icon and configure your Supabase URL and API key

### 3. Setup Flutter App

1. Install dependencies:
   ```bash
   cd flutter-app
   flutter pub get
   flutter pub run build_runner build
   ```

2. Update `lib/main.dart` with your Supabase credentials:
   ```dart
   final supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
   final anonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

3. Run the app:
   ```bash
   # For Windows desktop
   flutter run -d windows
   
   # For Android (with device connected)
   flutter run -d android
   ```

## 📋 Phase 1 Features

### Browser Extension
- ✅ Right-click context menu to save URLs
- ✅ Automatic detection of articles vs videos
- ✅ YouTube special handling
- ✅ Offline queue for failed saves
- ✅ Configuration UI for Supabase settings

### Flutter App
- ✅ Reading tab (articles)
- ✅ Viewing tab (videos)  
- ✅ Archive tab (completed items)
- ✅ Item cards with thumbnails and metadata
- ✅ Mark as read/watched
- ✅ Open URLs in browser
- ✅ Manual URL addition
- ✅ Delete items with confirmation
- ✅ Pull-to-refresh
- ✅ Error handling and empty states

### Backend
- ✅ URL metadata extraction
- ✅ YouTube video processing
- ✅ Image URL resolution
- ✅ Deduplication
- ✅ Event logging for analytics (Phase 3)

## 🔮 Coming in Phase 2

- Tags and tag management
- Search and filtering
- Advanced item organization
- Preset tags system

## 🔮 Coming in Phase 3

- Analytics dashboard
- Usage metrics and charts
- Completion tracking
- Streak counters

## 🏗️ Project Structure

```
shelfie/
├── prd.md                          # Product Requirements Document
├── backend/
│   └── supabase/
│       ├── config.toml             # Supabase configuration
│       ├── migrations/             # Database schema
│       └── functions/
│           └── save-url/           # Edge Function for URL processing
├── browser-extension/
│   ├── manifest.json               # Extension manifest
│   ├── background.js               # Service worker
│   ├── content.js                  # Content script
│   ├── popup.html                  # Configuration UI
│   └── popup.js                    # Popup logic
└── flutter-app/
    ├── pubspec.yaml                # Dependencies
    ├── lib/
    │   ├── main.dart               # App entry point
    │   ├── models/                 # Data models
    │   ├── services/               # API services
    │   ├── providers/              # State management
    │   ├── screens/                # UI screens
    │   └── widgets/                # Reusable components
    └── ...
```

## 🐛 Troubleshooting

### Supabase CLI Issues
- **"supabase is not recognized"**: Install the CLI using Chocolatey, Scoop, or direct download
- **npm global install error**: Use `npx supabase` instead of global install
- **Permission errors**: Run terminal as administrator
- **Can't install CLI**: Use the manual setup method in `SETUP-NO-CLI.md`
- **Alternative**: Use `npx supabase` commands without global installation

### Extension Issues
- Make sure your Supabase URL and API key are correctly configured
- Check the browser console for error messages
- Verify CORS settings in Supabase

### Flutter App Issues
- Run `flutter pub get` to ensure dependencies are installed
- Run `flutter pub run build_runner build` to generate code
- Check that Supabase credentials are correctly set in main.dart

### Backend Issues
- Verify Edge Function is deployed with `supabase functions list`
- Check Edge Function logs with `supabase functions logs save-url`
- Ensure database migration ran successfully

## 🎯 Testing Phase 1

1. **Extension**: Right-click on any webpage → "Save to Read/Watch Later"
2. **App**: Open Flutter app and see the item appear in Reading or Viewing tab
3. **Complete**: Mark item as read/watched and see it move to Archive
4. **Manual Add**: Use the + button in app to manually add URLs
5. **Delete**: Use delete button to remove items

Phase 1 provides the core MVP functionality for saving and consuming content across devices!
