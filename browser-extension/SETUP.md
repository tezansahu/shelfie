# Shelfie Browser Extension Setup

## ⚠️ Important Security Notice

The `config.js` file contains real Supabase credentials and is **excluded from Git** for security reasons. The extension uses a template-based configuration system to protect your API keys.

## 🚀 Quick Setup

### 1. Configure Supabase Credentials

1. **Copy the template**:
   ```bash
   cd browser-extension
   copy config.template.js config.js
   ```

2. **Get your Supabase credentials**:
   - Go to [Supabase Dashboard](https://supabase.com/dashboard)
   - Select your project → **Settings** → **API**
   - Copy **Project URL** and **anon public** key

3. **Update `config.js`** with your real credentials:
   ```javascript
   const SHELFIE_CONFIG = {
     supabase: {
       url: 'https://your-project-id.supabase.co', // Your actual Supabase URL
       anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...', // Your actual anon key
     },
     // ... rest of config
   };
   ```

### 2. Load the Extension

1. Open Chrome/Edge and go to `chrome://extensions/` or `edge://extensions/`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select the `browser-extension` folder
5. The extension should load with a green "Ready" status

### 3. Test the Extension

1. Click the Shelfie extension icon - should show "Ready to save!"
2. Right-click any webpage → "Save to Read/Watch Later"
3. Check your Supabase project to see the saved item

## 🔒 Security & File Structure

```
browser-extension/
├── config.template.js  ✅ Safe to commit (no real credentials)
├── config.js          🚫 Ignored by Git (contains real credentials)
├── manifest.json
├── background.js
└── ...
```

### For New Team Members

When setting up this project:
1. Clone the repository
2. Copy `config.template.js` to `config.js`
3. Get Supabase credentials from project admin
4. Update `config.js` with real credentials
5. Load the extension in Chrome/Edge

## Production Deployment

For production/distribution, you would:

1. **Build Process**: Create a build script that injects the credentials during packaging
2. **Environment Variables**: Use different configs for dev/staging/production
3. **Secure Distribution**: Package the extension with credentials already configured

## Alternative: Environment-based Config

You can also create multiple config files:

```
browser-extension/
├── config.js (default/template)
├── config.dev.js (development)
├── config.prod.js (production)
└── ...
```

Then update the manifest to load the appropriate config based on environment.

## Benefits of This Approach

- ✅ **User-friendly**: No manual credential entry required
- ✅ **Secure**: Credentials are bundled during build, not exposed in UI
- ✅ **Professional**: Like other browser extensions (LastPass, etc.)
- ✅ **Maintainable**: Easy to update credentials during deployment
- ✅ **Scalable**: Supports multiple environments/configurations

## Development Workflow

1. Developer updates `config.js` with their Supabase credentials
2. Tests extension locally
3. For distribution, build process injects production credentials
4. Users get a pre-configured extension that "just works"
