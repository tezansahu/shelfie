# Shelfie - Personal Read & Watch Later System

## Current Status: Phase 3 Complete! 🎉

**Phase 1** (MVP Save & Consume) ✅ Complete  
**Phase 2** (Tags, Search, Filters) ✅ Complete  
**Phase 3** (Analytics) ✅ Complete  

## ✅ What's Included (Phases 1-3)

### 🗄️ Database (Supabase)
- Complete PostgreSQL schema with items, users, tags, item_tags, and events tables
- Advanced search functions with full-text search (pg_trgm)
- Preset tag seeding (17+ categories)
- Triggers for automatic timestamp updates and status management
- Views for efficient data access with tag aggregation
- **Phase 3**: Events tracking and analytics_summary() RPC function

### 🔧 Backend (Supabase Edge Functions)
- `save-url` - URL processing and metadata extraction (Phase 1)
- `add-item-manual` - Manual URL addition from app (Phase 2)
- `list-presets` - Tag discovery and management (Phase 2)
- YouTube video detection and thumbnail extraction
- HTML metadata parsing with advanced heuristics
- Deduplication and error handling
- **Phase 3**: Automatic event logging for analytics

### 🌐 Browser Extension (Chrome/Edge)
- Manifest V3 compatible with context menu integration
- Right-click "Save to Read/Watch Later" functionality
- Configuration popup for Supabase credentials
- Offline queue for failed saves with retry logic
- Visual feedback and notifications

### 📱 Flutter App (Windows Desktop + Android)
- **Phase 1 Features:**
  - Material 3 design with light/dark theme support
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
- **Intelligent UX**:
  - Expandable filter interface with active filter indicators
  - Tab-specific auto-filtering (hidden from user on Reading/Viewing tabs)
  - Archive tab supports both content types with manual filtering

## 🧪 Testing Your Setup

### Core Functionality Testing
1. **Save from Extension**: Right-click on any webpage → "Save to Read/Watch Later"
2. **View in App**: Open Flutter app and see items in Reading/Viewing tabs
3. **Mark Complete**: Mark items as read/watched and see them move to Archive
4. **Manual Add**: Use the + button to manually add URLs
5. **Delete Items**: Use delete button to remove items

### Phase 2 Feature Testing  
6. **Tag Management**: Click tag icon on item cards to add/remove tags
7. **Search Functionality**: Use search bar to find items by title/description/domain
8. **Tag Filtering**: Use filter controls to show items with specific tags
9. **Smart Tab Filtering**: Switch between Reading/Viewing tabs to see auto-filtering
10. **Custom Tags**: Create new tags through the tag selector dialog
11. **Combined Filtering**: Use search + tag filters together
12. **Filter Clearing**: Test individual and bulk filter clearing

## 📚 Documentation & Status

- **[PHASE1-STATUS.md](PHASE1-STATUS.md)** - Complete Phase 1 implementation details
- **[PHASE2-STATUS.md](PHASE2-STATUS.md)** - Complete Phase 2 implementation details  
- **[prd.md](prd.md)** - Full product requirements and technical specifications

## 🗂️ Next Phase - Analytics

**Phase 3** will include:
- Content consumption analytics and metrics
- Reading/watching streaks and habits
- Tag usage analytics and trends  
- Time-based completion statistics
- Domain and source analysis

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
- **Can't install CLI**: Use the manual setup method in database migrations
- **Alternative**: Use `npx supabase` commands without global installation

### Extension Issues
- Make sure your Supabase URL and API key are correctly configured
- Check the browser console for error messages
- Verify CORS settings in Supabase
- Test the extension on different websites

### Flutter App Issues
- Run `flutter pub get` to ensure dependencies are installed
- Run `flutter pub run build_runner build` to generate code
- Check that Supabase credentials are correctly set in main.dart
- Verify Flutter SDK version (3.8.1+)

### Backend Issues
- Verify Edge Functions are deployed with `supabase functions list`
- Check Edge Function logs with `supabase functions logs`
- Ensure database migrations ran successfully
- Test tag functionality and search operations

## 🎯 What's Working

✅ **Save & Consume Pipeline**: Browser extension → Supabase → Flutter app  
✅ **Content Organization**: Reading/Viewing tabs with smart filtering  
✅ **Tag System**: Preset and custom tags with full management  
✅ **Advanced Search**: Full-text search with tag filtering  
✅ **Cross-Platform**: Windows desktop and Android apps  
✅ **Rich Metadata**: Automatic extraction for articles and YouTube videos  
✅ **Smart UX**: Tab-specific auto-filtering and intelligent UI  

**Phase 1 & 2 provide a complete personal knowledge management system!** 📚✨

---

*Ready for Phase 3 analytics to track your reading habits and optimize your knowledge consumption!*
