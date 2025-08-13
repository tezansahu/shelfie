// Background script for Shelfie browser extension
// Import configuration
importScripts('config.js');

console.log('Shelfie background script loaded');

// Get configuration from config.js
const getConfig = () => {
  return self.SHELFIE_CONFIG || {
    supabase: {
      url: 'YOUR_SUPABASE_PROJECT_URL',
      anonKey: 'YOUR_SUPABASE_ANON_KEY'
    },
    app: { name: 'Shelfie', version: '1.0.0', debug: false },
    features: { offlineQueue: true, notifications: true, contentScript: true }
  };
};

// Check if configuration is properly set
const isConfigured = () => {
  const config = getConfig();
  return config.supabase.url !== 'YOUR_SUPABASE_PROJECT_URL' && 
         config.supabase.url !== 'https://your-project-id.supabase.co' &&
         config.supabase.anonKey !== 'YOUR_SUPABASE_ANON_KEY' &&
         config.supabase.anonKey !== 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' &&
         config.supabase.url.startsWith('https://') &&
         config.supabase.anonKey.length > 50;
};

// Initialize extension
chrome.runtime.onInstalled.addListener(async () => {
  console.log('Shelfie extension installed');
  
  // Always create context menu first, then check configuration
  createContextMenu();
  
  // Check if properly configured
  if (!isConfigured()) {
    console.warn('Shelfie not configured - please update config.js with your Supabase credentials');
    // Show setup notification
    if (getConfig().features.notifications) {
      showNotification('Setup Required', 'Please configure Supabase credentials in config.js');
    }
  } else {
    console.log('Shelfie is properly configured');
  }
});

// Create context menu item
function createContextMenu() {
  try {
    chrome.contextMenus.removeAll(() => {
      chrome.contextMenus.create({
        id: 'save-to-shelfie',
        title: 'Save to Read/Watch Later',
        contexts: ['page', 'link', 'selection']
      }, () => {
        if (chrome.runtime.lastError) {
          console.error('Context menu creation error:', chrome.runtime.lastError);
        } else {
          console.log('Context menu created successfully');
        }
      });
    });
  } catch (error) {
    console.error('Error creating context menu:', error);
  }
}

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'save-to-shelfie') {
    const url = info.linkUrl || tab.url;
    await saveUrl(url, tab);
  }
});

// Handle keyboard shortcut (can be added later)
chrome.commands?.onCommand.addListener(async (command) => {
  if (command === 'save-current-page') {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab.url) {
      await saveUrl(tab.url, tab);
    }
  }
});

// Save URL to Shelfie
async function saveUrl(url, tab) {
  try {
    console.log(`Saving URL: ${url}`);
    
    // Get configuration
    const config = getConfig();
    
    if (!isConfigured()) {
      showNotification('Setup Required', 'Shelfie not configured - check config.js');
      return;
    }
    
    // Detect browser platform
    const platform = getBrowserPlatform();
    
    // Prepare request
    const endpoint = `${config.supabase.url}/functions/v1/save-url`;
    const payload = {
      url: url,
      source_client: 'browser_extension',
      source_platform: platform
    };
    
    // Show loading notification
    if (config.features.notifications) {
      showNotification('Saving...', 'Adding to your reading list');
    }
    
    // Make request to Edge Function
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.supabase.anonKey}`,
        'apikey': config.supabase.anonKey
      },
      body: JSON.stringify(payload)
    });
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => null);
      throw new Error(errorData?.error || `HTTP ${response.status}`);
    }
    
    const result = await response.json();
    
    // Show success notification
    if (result.existing) {
      showNotification('Already Saved', 'This item is already in your list');
    } else {
      const title = result.title || 'Item';
      const type = result.content_type === 'video' ? 'video' : 'article';
      showNotification('Saved!', `${title} added to ${type}s`);
    }
    
    // Update badge
    setBadge('✓', '#4CAF50');
    setTimeout(() => setBadge('', ''), 2000);
    
  } catch (error) {
    console.error('Failed to save URL:', error);
    
    // Try to queue for later if it's a network error
    if (error.message.includes('fetch') || error.message.includes('network')) {
      await queueForLater(url, tab);
      showNotification('Queued', 'Will sync when online');
    } else {
      showNotification('Failed to Save', error.message);
    }
    
    // Update badge
    setBadge('!', '#F44336');
    setTimeout(() => setBadge('', ''), 3000);
  }
}

// Queue URL for later syncing (offline support)
async function queueForLater(url, tab) {
  const queue = await chrome.storage.local.get(['queue']) || { queue: [] };
  
  queue.queue.push({
    url: url,
    title: tab.title,
    timestamp: Date.now(),
    source_client: 'browser_extension',
    source_platform: getBrowserPlatform()
  });
  
  await chrome.storage.local.set({ queue: queue.queue });
  
  // Set up periodic retry
  chrome.alarms.create('retry-queue', { delayInMinutes: 5 });
}

// Process queued items
chrome.alarms?.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'retry-queue') {
    await processQueue();
  }
});

// Process offline queue
async function processQueue() {
  const queue = await chrome.storage.local.get(['queue']);
  if (!queue.queue || queue.queue.length === 0) return;
  
  const config = getConfig();
  if (!isConfigured()) return;
  
  const processed = [];
  const remaining = [];
  
  for (const item of queue.queue) {
    try {
      const endpoint = `${config.supabase.url}/functions/v1/save-url`;
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.supabase.anonKey}`,
          'apikey': config.supabase.anonKey
        },
        body: JSON.stringify(item)
      });
      
      if (response.ok) {
        processed.push(item);
      } else {
        remaining.push(item);
      }
    } catch (error) {
      remaining.push(item);
    }
  }
  
  // Update queue
  await chrome.storage.local.set({ queue: remaining });
  
  // Show notification if items were processed
  if (processed.length > 0) {
    showNotification('Synced', `${processed.length} item(s) saved`);
  }
  
  // Schedule next retry if items remain
  if (remaining.length > 0) {
    chrome.alarms.create('retry-queue', { delayInMinutes: 10 });
  }
}

// Detect browser platform
function getBrowserPlatform() {
  const userAgent = navigator.userAgent;
  if (userAgent.includes('Chrome')) return 'chrome';
  if (userAgent.includes('Edge')) return 'edge';
  return 'unknown';
}

// Show notification
function showNotification(title, message) {
  if (chrome.notifications) {
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icons/icon-48.png',
      title: title,
      message: message
    });
  }
}

// Set badge text and color
function setBadge(text, color) {
  chrome.action.setBadgeText({ text: text });
  if (color) {
    chrome.action.setBadgeBackgroundColor({ color: color });
  }
}

// Handle messages from popup or content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'save-current-url') {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      if (tabs[0]?.url) {
        saveUrl(tabs[0].url, tabs[0]);
        sendResponse({ success: true });
      } else {
        sendResponse({ success: false, error: 'No active tab' });
      }
    });
    return true; // Keep message channel open for async response
  }
  
  if (request.action === 'get-config') {
    const config = getConfig();
    sendResponse({
      configured: isConfigured(),
      appName: config.app.name,
      version: config.app.version,
      features: config.features
    });
    return true;
  }
  
  if (request.action === 'check-status') {
    sendResponse({
      configured: isConfigured(),
      ready: isConfigured()
    });
    return true;
  }
});
