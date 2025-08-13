// Configuration template for Shelfie browser extension
// Copy this file to config.js and add your real Supabase credentials
// This template file is safe to commit to Git

const SHELFIE_CONFIG = {
  // Supabase configuration
  supabase: {
    url: 'https://your-project-id.supabase.co', // Replace with your actual Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', // Replace with your actual anon key
  },
  
  // App configuration
  app: {
    name: 'Shelfie',
    version: '1.0.0',
    debug: false, // Set to true for development
  },
  
  // Feature flags
  features: {
    offlineQueue: true,
    notifications: true,
    contentScript: true,
  }
};

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SHELFIE_CONFIG;
}

// Make available globally for browser extension
if (typeof window !== 'undefined') {
  window.SHELFIE_CONFIG = SHELFIE_CONFIG;
}

// For service worker context
if (typeof self !== 'undefined') {
  self.SHELFIE_CONFIG = SHELFIE_CONFIG;
}
