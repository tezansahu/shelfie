// Content script for Shelfie extension
console.log('Shelfie content script loaded');

// Extract page metadata as fallback
function extractPageMetadata() {
  const metadata = {};
  
  // Title
  metadata.title = document.title;
  
  // Description
  const descMeta = document.querySelector('meta[name="description"]');
  const ogDescMeta = document.querySelector('meta[property="og:description"]');
  metadata.description = descMeta?.content || ogDescMeta?.content || '';
  
  // Image
  const ogImageMeta = document.querySelector('meta[property="og:image"]');
  const twitterImageMeta = document.querySelector('meta[name="twitter:image"]');
  metadata.image = ogImageMeta?.content || twitterImageMeta?.content || '';
  
  // Canonical URL
  const canonicalLink = document.querySelector('link[rel="canonical"]');
  metadata.canonical = canonicalLink?.href || '';
  
  // Domain
  metadata.domain = window.location.hostname;
  
  // URL
  metadata.url = window.location.href;
  
  return metadata;
}

// Listen for requests from background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'extract-metadata') {
    const metadata = extractPageMetadata();
    sendResponse(metadata);
  }
});

// Optional: Add keyboard shortcut handler
document.addEventListener('keydown', (event) => {
  // Ctrl+Shift+S (or Cmd+Shift+S on Mac)
  if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'S') {
    event.preventDefault();
    
    // Send message to background script to save current page
    chrome.runtime.sendMessage({ action: 'save-current-url' }, (response) => {
      if (response?.success) {
        console.log('Page saved to Shelfie');
      } else {
        console.error('Failed to save page:', response?.error);
      }
    });
  }
});

// Optional: Add visual feedback for successful saves
function showSaveConfirmation() {
  // Create a temporary notification element
  const notification = document.createElement('div');
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: #4CAF50;
    color: white;
    padding: 12px 20px;
    border-radius: 6px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    z-index: 10000;
    font-family: system-ui, -apple-system, sans-serif;
    font-size: 14px;
    animation: slideIn 0.3s ease-out;
  `;
  
  notification.textContent = '✓ Saved to Shelfie';
  
  // Add slide-in animation
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideIn {
      from { transform: translateX(100%); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }
  `;
  document.head.appendChild(style);
  
  document.body.appendChild(notification);
  
  // Remove after 3 seconds
  setTimeout(() => {
    notification.style.animation = 'slideIn 0.3s ease-out reverse';
    setTimeout(() => {
      notification.remove();
      style.remove();
    }, 300);
  }, 3000);
}

// Listen for save confirmations from background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'show-save-confirmation') {
    showSaveConfirmation();
  }
});
