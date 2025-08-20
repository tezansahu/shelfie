# Shelfie - Personal Read & Watch Later System

Shelfie is a lightweight, cross-platform **"read & watch later" system** that captures links from a **browser extension**, stores them in a **Supabase backend**, and presents them in a polished **Flutter app (Windows desktop + Android)**. 

It focuses on fast saving, organized consumption (tags, search, filters), and built-in analytics to help you manage your backlog.

How users can use Shelfie:

- **Save instantly from your browser:** right-click → "Save to Read/View Later" (extension sends the URL to a Supabase Edge Function that fetches metadata and creates the item).
- **Consume in the app:** items appear under Reading (articles) or Viewing (videos) with thumbnails and snippets — open in browser, mark complete, or add tags.
- **Organize & find:** preset + custom tags, fuzzy search, and filters make it quick to find what to read/watch next.
- **Learn from usage:** built-in analytics (completion rates, time-to-complete, domain and tag trends) helps reduce backlog and improve focus.

## Quick preview
A quick look at the browser extension and Flutter app UI to give a glimpse of the product.

### Browser Extension

<table>
  <tr>
    <td align="center">
      <img src="assets/extension-1.png" alt="Extension - popup" width="320" />
    </td>
    <td align="center">
      <img src="assets/extension-2.png" alt="Extension - context save" width="320" />
    </td>
  </tr>
</table>

### Mobile App
<table>
  <tr>
    <td align="center">
      <img src="assets/app-screen-0.png" alt="App screen 0" width="260" />
    </td>
    <td align="center">
      <img src="assets/app-screen-1.png" alt="App screen 1" width="260" />
    </td>
    <td align="center">
      <img src="assets/app-screen-2.png" alt="App screen 2" width="260" />
    </td>
    <td align="center">
      <img src="assets/app-screen-3.png" alt="App screen 3" width="260" />
    </td>
  </tr>
</table>

**Phase 1** (MVP Save & Consume) ✅ Complete  
**Phase 2** (Tags, Search, Filters) ✅ Complete  
**Phase 3** (Analytics) ✅ Complete  
**UI Modernization** ✅ Complete  
**Mobile Optimization** ✅ Complete  
**Google OAuth Integration** ✅ Complete  

## ✅ What's Included (All Phases Complete)

### 🗄️ Database (Supabase)
- Complete PostgreSQL schema with items, users, tags, item_tags, and events tables
- Advanced search functions with full-text search (pg_trgm)
- Preset tag seeding (17+ categories)
- Triggers for automatic timestamp updates and status management
- Views for efficient data access with tag aggregation
- **Phase 3**: Events tracking and analytics_summary() RPC function
- **Latest**: Fixed delete trigger timing to prevent foreign key constraint violations

### 🔧 Backend (Supabase Edge Functions)
- `save-url` - URL processing and metadata extraction (Phase 1)
- `add-item-manual` - Manual URL addition from app (Phase 2)
- `list-presets` - Tag discovery and management (Phase 2)
- YouTube video detection and thumbnail extraction
- HTML metadata parsing with advanced heuristics
- Deduplication and error handling
- **Phase 3**: Automatic event logging for analytics
- **Latest**: Robust deletion handling with proper event logging

### 🌐 Browser Extension (Chrome/Edge)
- Manifest V3 compatible with context menu integration
- Sign in with Google account
- Right-click "Save to Read/Watch Later" functionality
- Configuration popup for Supabase credentials (streamlined interface)
- Offline queue for failed saves with retry logic
- Visual feedback and notifications
- **Latest**: Removed unnecessary "Open Shelfie App" button for cleaner UX

### 📱 Flutter App (Windows Desktop + Android)
- **Phase 1 Features:**
  - Material 3 design with modern #596BFB color palette
  - Four main tabs: Reading, Viewing, Archive, Analytics
  - Item cards with thumbnails, titles, and metadata
  - Mark as read/watched functionality
  - Manual URL addition and deletion
  - Pull-to-refresh and comprehensive error handling

- **Phase 2 Features:**
  - **Tag System:** Preset and custom tags with visual indicators
  - **Search & Filters:** Full-text search across titles, descriptions, domains
  - **Smart Filtering:** Auto content-type filtering per tab (Reading=Articles, Viewing=Videos)
  - **Tag Management:** Add/remove tags with usage counts and selector dialog
  - **Advanced UI:** Expandable filter interface with active filter indicators

- **Phase 3 Features:**
  - **Analytics Dashboard:** Comprehensive metrics and visual insights
  - **Interactive Charts:** Weekly trends, tag analysis, domain stats, backlog distribution
  - **Key Metrics:** Pending items, completion rates, time-to-complete, streak tracking
  - **Date Range Selection:** Configurable analysis periods (7d to 1 year)
  - **Real-time Updates:** Analytics refresh when items are modified
  - **Visual Design:** Professional charts with fl_chart library

- **UI Modernization & Mobile Optimization:**
  - **Modern Design:** Gradient headers, rounded corners, enhanced shadows
  - **Brand Color Palette:** Primary #596BFB with complementary variants
  - **Responsive Design:** Mobile-optimized layouts for Android devices
  - **Mobile Navigation:** Icon-only tabs on mobile with tooltips for accessibility
  - **Optimized Cards:** Equal-weight action buttons with shortened text
  - **Analytics Mobile:** Responsive metric grids and chart sizing for mobile viewing
  - **Cross-Platform:** Consistent experience across Windows desktop and Android

- **Google OAuth Integration:**
  - Uses a Google Web Client ID via `AppConfig.googleWebClientId` (see `lib/config/app_config.dart`).
  - Signs in with Google, then exchanges tokens with Supabase Auth to obtain a Supabase session (JWT + refresh token).
  - Session is managed by Supabase (auto-refresh enabled) and used for all DB/Edge Function calls.
  - RLS enforced automatically: requests run as the authenticated user (`auth.uid()`), isolating user data.
  - Sign-in/out handled by `AuthService` with a simple one-tap flow and clear error states.
  - Consistent auth across app and extension: the same Supabase project and Google Web client are used.


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
4. Click the extension icon and sign in with Google in the popup (no API key entry needed)

> Note: The extension reads your Supabase URL and anon key from `browser-extension/config.js` during development.

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
   
   # To build APK for Android deployment
   flutter build apk --release
   ```

## 📋 Implemented Features

### Phase 1 - MVP Save & Consume ✅
- **Save from Browser**: Right-click context menu to save articles and videos
- **Cross-Platform App**: Windows desktop and Android support  
- **Content Organization**: Reading (articles) and Viewing (videos) tabs
- **Item Management**: Mark as read/watched, archive, delete
- **Manual URL Addition**: Add URLs directly from the app
- **Rich Metadata**: Automatic title, description, and thumbnail extraction
- **YouTube Support**: Special handling for YouTube videos with thumbnails

### Phase 2 - Tags, Search, Filters ✅
- **Tag System**: 17+ preset tags (ai-ml, engineering, product, etc.) + custom tags
- **Advanced Search**: Full-text search across titles, descriptions, and domains
- **Smart Filtering**: 
  - Auto content-type filtering per tab (Reading=Articles, Viewing=Videos)
  - Multi-select tag filtering with usage counts
  - Combined search + filter functionality
- **Tag Management**: 
  - Add/remove tags from items with visual selector
  - Preset vs custom tag distinction with icons
  - Tag usage analytics and counts

### Phase 3 - Analytics ✅
- **Comprehensive Dashboard**: Visual metrics and insights into reading/viewing habits
- **Key Metrics Tiles**:
  - Pending items count (reading vs viewing breakdown)
  - Recent completions (7-day and 30-day)
  - Completion rate percentage
  - Average and median time to complete
  - Current streak tracking with motivation
- **Interactive Charts**:
  - Weekly completion trends (12-week bar chart)
  - Top tags analysis (pie chart ≤5 tags, bar chart >5 tags)
  - Domain completion rates (progress bars)
  - Backlog age distribution (pie chart with legend)
- **Date Range Selection**: Configurable analysis periods (7 days to 1 year)
- **Automatic Event Tracking**: All item actions logged for historical analysis
- **Real-time Updates**: Analytics refresh when items are modified

### UI Modernization & Mobile Optimization ✅
- **Modern Design System**: 
  - Custom #596BFB brand color palette with variants
  - Material 3 design with gradient effects and enhanced shadows
  - Consistent typography and spacing throughout the app
- **Mobile-First Responsive Design**:
  - Adaptive navigation (icon-only tabs on mobile, icon+text on desktop)
  - Responsive metric grids (2 columns on mobile, 4 on desktop)
  - Mobile-optimized chart sizing and spacing
  - Touch-friendly button sizing and spacing
- **Enhanced UX**:
  - Shortened button text to prevent wrapping ("Read" vs "Mark as Read")
  - Equal-weight action buttons for better visual balance
  - Tooltips for accessibility on icon-only mobile navigation
  - Streamlined browser extension interface
- **Cross-Platform Consistency**: Unified experience across Windows and Android

## 🧪 Testing Your Setup

### Core Functionality Testing
1. **Save from Extension**: Right-click on any webpage → "Save to Read/Watch Later"
2. **View in App**: Open Flutter app and see items in Reading/Viewing tabs
3. **Mark Complete**: Mark items as read/watched and see them move to Archive
4. **Manual Add**: Use the + button to manually add URLs
5. **Delete Items**: Use delete button to remove items (now working properly!)

### Phase 2 Feature Testing  
6. **Tag Management**: Click tag icon on item cards to add/remove tags
7. **Search Functionality**: Use search bar to find items by title/description/domain
8. **Tag Filtering**: Use filter controls to show items with specific tags
9. **Smart Tab Filtering**: Switch between Reading/Viewing tabs to see auto-filtering
10. **Custom Tags**: Create new tags through the tag selector dialog
11. **Combined Filtering**: Use search + tag filters together
12. **Filter Clearing**: Test individual and bulk filter clearing

### Phase 3 Analytics Testing
13. **Analytics Dashboard**: Navigate to Analytics tab to view comprehensive metrics
14. **Interactive Charts**: Explore weekly trends, tag analysis, and domain statistics
15. **Date Range Selection**: Change analysis periods to see different data views
16. **Real-time Updates**: Add/complete items and see analytics refresh automatically

### Mobile & UI Testing
17. **Responsive Design**: Test app on both Windows desktop and Android device
18. **Mobile Navigation**: Verify icon-only tabs on mobile with functional tooltips
19. **Mobile Analytics**: Check that metric cards and charts display properly on mobile
20. **Cross-Platform Consistency**: Compare UI experience between platforms

## 📚 Documentation & Status

- **[PHASE1-STATUS.md](PHASE1-STATUS.md)** - Complete Phase 1 implementation details
- **[PHASE2-STATUS.md](PHASE2-STATUS.md)** - Complete Phase 2 implementation details  
- **[PHASE3-STATUS.md](PHASE3-STATUS.md)** - Complete Phase 3 analytics implementation
- **[prd.md](prd.md)** - Full product requirements and technical specifications

## 🎯 Project Complete! 

**Shelfie** is now a fully-featured personal read & watch later system with:
- ✅ Cross-platform save & consume pipeline
- ✅ Advanced tagging and search capabilities  
- ✅ Comprehensive analytics and insights
- ✅ Modern, mobile-optimized UI design
- ✅ Robust error handling and user experience

### Browser Extension
- ✅ Right-click context menu to save URLs
- ✅ Automatic detection of articles vs videos
- ✅ YouTube special handling
- ✅ Offline queue for failed saves
- ✅ Streamlined configuration UI (removed unnecessary buttons)

### Flutter App  
- ✅ Modern Material 3 design with #596BFB brand colors
- ✅ Reading tab (articles) with responsive design
- ✅ Viewing tab (videos) with mobile optimization
- ✅ Archive tab (completed items) with cross-platform consistency
- ✅ Analytics tab with comprehensive metrics and charts
- ✅ Item cards with thumbnails, metadata, and equal-weight action buttons
- ✅ Mark as read/watched with shortened button text
- ✅ Open URLs in browser with proper handling
- ✅ Manual URL addition and robust deletion
- ✅ Advanced tag system with preset and custom tags
- ✅ Search and filtering with full-text capabilities
- ✅ Pull-to-refresh and comprehensive error handling
- ✅ Mobile-responsive navigation (icon-only tabs on small screens)

### Backend
- ✅ URL metadata extraction with enhanced processing
- ✅ YouTube video processing with thumbnail generation
- ✅ Image URL resolution and optimization
- ✅ Deduplication and comprehensive error handling
- ✅ Event logging for analytics with proper trigger timing
- ✅ Advanced search functions and tag management
- ✅ Robust deletion handling with foreign key constraint fixes

## 🏗️ Project Structure

```
shelfie/
├── prd.md                          # Product Requirements Document
├── PHASE1-STATUS.md               # Phase 1 implementation details
├── PHASE2-STATUS.md               # Phase 2 implementation details  
├── PHASE3-STATUS.md               # Phase 3 analytics implementation
├── backend/
│   └── supabase/
│       ├── config.toml             # Supabase configuration
│       ├── migrations/             # Database schema with all phases
│       └── functions/
│           ├── save-url/           # URL processing Edge Function
│           ├── add-item-manual/    # Manual addition Edge Function
│           └── list-presets/       # Tag management Edge Function
├── browser-extension/
│   ├── manifest.json               # Extension manifest
│   ├── background.js               # Service worker
│   ├── content.js                  # Content script
│   ├── popup.html                  # Streamlined configuration UI
│   └── popup.js                    # Popup logic
└── flutter-app/
    ├── pubspec.yaml                # Dependencies
    ├── lib/
    │   ├── main.dart               # App entry point with modern theming
    │   ├── models/                 # Data models (items, tags, analytics)
    │   ├── services/               # API services  
    │   ├── providers/              # State management with Riverpod
    │   ├── screens/                # UI screens (home, analytics)
    │   └── widgets/                # Reusable components (cards, charts)
    └── ...
```

## 🎯 What's Working

✅ **Complete Read & Watch Later System**: Browser extension → Supabase → Cross-platform Flutter app  
✅ **Content Organization**: Smart Reading/Viewing tabs with auto-filtering  
✅ **Advanced Tag System**: Preset and custom tags with full management capabilities  
✅ **Powerful Search & Filters**: Full-text search with multi-tag filtering  
✅ **Analytics & Insights**: Comprehensive dashboard with interactive charts and metrics  
✅ **Modern Mobile-First Design**: Responsive UI optimized for both desktop and mobile  
✅ **Cross-Platform Support**: Windows desktop and Android with consistent experience  
✅ **Rich Metadata Extraction**: Automatic processing for articles and YouTube videos  
✅ **Robust Error Handling**: Proper deletion, offline queuing, and user feedback  

**Shelfie provides a complete, production-ready personal knowledge management system!** 📚✨

## 🚀 Deployment Ready

The system is now production-ready with:
- **Browser Extension**: Publishable to Chrome Web Store / Edge Add-ons
- **Flutter App**: Ready for Google Play Store and Microsoft Store distribution  
- **Backend**: Scalable Supabase infrastructure with proper event logging
- **Mobile Optimization**: Responsive design tested on Android devices
- **Error Handling**: Comprehensive error states and user feedback

---

*Shelfie: Your personal reading and watching companion, designed for the modern knowledge worker.* 🎯

---

## 🔐 Google OAuth Integration

Shelfie uses Google Sign‑In end to end, anchored by Supabase Auth.

- Supabase is the identity provider broker. You configure a Google Web client in Supabase. Supabase handles the Google OAuth redirect and issues a Supabase session (JWT + refresh token).
- Flutter app signs in with Google using the same Web client and exchanges the tokens with Supabase. The app then uses the Supabase session to call the database and Edge Functions with Row Level Security (RLS).
- The Browser Extension uses a secure OAuth flow without publishing: it launches a web auth flow to Supabase’s Google provider and receives a Supabase session back. It stores the session (access + refresh token) locally and calls Edge Functions with Authorization: Bearer <Supabase JWT> so saving happens under the signed‑in user.

### Setup summary
1) Google Cloud Console → Credentials → Web client (used by both app and Supabase)
  - Authorized redirect URI must include:
    - `https://<YOUR_SUPABASE_PROJECT>.supabase.co/auth/v1/callback`

2) Supabase Dashboard → Authentication → Providers → Google
  - Paste the Web client’s Client ID and Secret.

3) Supabase Dashboard → Authentication → URL Configuration → Redirect URLs
  - Add the extension’s runtime redirect URL (Chrome intercepts this URL, no publishing required):
    - `https://<your-extension-id>.chromiumapp.org/supabase`

4) Extension configuration
  - `browser-extension/config.js` must contain your Supabase URL and anon key for development.
  - The extension opens Supabase’s authorize endpoint with `redirect_to` set to the runtime URL returned by `chrome.identity.getRedirectURL('supabase')`.
  - On success, it stores the Supabase access token and refresh token.

### Why the chromiumapp URL looks “dead” in a browser
The `https://<id>.chromiumapp.org/*` URL is special; Chrome intercepts it for OAuth flows. Navigating to it directly will show DNS errors. This is expected. It only works within the `chrome.identity.launchWebAuthFlow` flow.

### Common pitfalls & fixes
- redirect_uri_mismatch from Google: Ensure Supabase’s Google provider uses the Web client, not a Chrome Extension client. The Web client must whitelist the Supabase callback URL exactly.
- Extension sign‑in fails: Verify the Supabase Redirect URLs include the exact chromiumapp URL with the path you pass to `getRedirectURL`.
- 401 calling Edge Functions: The extension must send `Authorization: Bearer <Supabase access token>` and `apikey: <anon key>`. If 401 persists, refresh the token using the stored refresh token via Supabase’s `/auth/v1/token?grant_type=refresh_token`.

### Security and RLS
All database access is protected by RLS with policies bound to `auth.uid()`. Edge Functions receive the user’s Supabase JWT via the Authorization header and call the database with that context. This guarantees items are stored and read only for the authenticated user.
