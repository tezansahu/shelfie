// Popup script for Shelfie extension
document.addEventListener('DOMContentLoaded', async () => {
  const saveCurrentBtn = document.getElementById('save-current');
  const openShelfieBtn = document.getElementById('open-shelfie');
  const statusReady = document.getElementById('status-ready');
  const statusNotConfigured = document.getElementById('status-not-configured');

  // Check configuration status
  await checkStatus();

  // Event listeners
  saveCurrentBtn.addEventListener('click', saveCurrentPage);
  openShelfieBtn.addEventListener('click', openShelfieApp);

  async function checkStatus() {
    try {
      const status = await new Promise((resolve) => {
        chrome.runtime.sendMessage({ action: 'check-status' }, resolve);
      });

      if (status.configured) {
        statusReady.classList.remove('hidden');
        statusNotConfigured.classList.add('hidden');
        saveCurrentBtn.disabled = false;
      } else {
        statusReady.classList.add('hidden');
        statusNotConfigured.classList.remove('hidden');
        saveCurrentBtn.disabled = true;
      }
    } catch (error) {
      console.error('Failed to check status:', error);
      statusReady.classList.add('hidden');
      statusNotConfigured.classList.remove('hidden');
      saveCurrentBtn.disabled = true;
    }
  }

  async function saveCurrentPage() {
    try {
      saveCurrentBtn.textContent = '⏳ Saving...';
      saveCurrentBtn.disabled = true;

      const result = await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({ action: 'save-current-url' }, (response) => {
          if (chrome.runtime.lastError) {
            reject(new Error(chrome.runtime.lastError.message));
          } else {
            resolve(response);
          }
        });
      });

      if (result && result.success) {
        saveCurrentBtn.textContent = '✅ Saved!';
        setTimeout(() => {
          saveCurrentBtn.textContent = '📝 Save Current Page';
          saveCurrentBtn.disabled = false;
        }, 2000);
      } else {
        throw new Error(result?.error || 'Failed to save');
      }
    } catch (error) {
      console.error('Failed to save current page:', error);
      saveCurrentBtn.textContent = '❌ Failed';
      setTimeout(() => {
        saveCurrentBtn.textContent = '📝 Save Current Page';
        saveCurrentBtn.disabled = false;
      }, 2000);
    }
  }

  async function openShelfieApp() {
    // This would open the Flutter app if it's running
    // For now, we'll show a message about opening the app
    chrome.tabs.create({
      url: 'chrome://apps/'
    });
  }
});
