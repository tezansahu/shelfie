// Popup script for Shelfie extension
document.addEventListener('DOMContentLoaded', async () => {
  const saveCurrentBtn = document.getElementById('save-current');
  const signInBtn = document.getElementById('sign-in');
  const signOutBtn = document.getElementById('sign-out');
  const statusReady = document.getElementById('status-ready');
  const statusNotConfigured = document.getElementById('status-not-configured');
  const statusAuthRequired = document.getElementById('status-auth-required');
  const userBar = document.getElementById('user-bar');
  const avatarImg = document.getElementById('avatar-img');
  const avatarFallback = document.getElementById('avatar-fallback');
  const userName = document.getElementById('user-name');
  const userEmail = document.getElementById('user-email');

  // Check configuration status
  await checkStatus();

  // Event listeners
  saveCurrentBtn.addEventListener('click', saveCurrentPage);
  signInBtn.addEventListener('click', signIn);
  signOutBtn.addEventListener('click', signOut);

  async function checkStatus() {
    try {
      const status = await new Promise((resolve) => {
        chrome.runtime.sendMessage({ action: 'check-status' }, resolve);
      });

      if (!status.configured) {
        statusReady.classList.add('hidden');
        statusNotConfigured.classList.remove('hidden');
        statusAuthRequired.classList.add('hidden');
        signInBtn.classList.add('hidden');
        saveCurrentBtn.classList.add('hidden');
        signOutBtn.classList.add('hidden');
        userBar.classList.remove('visible');
        saveCurrentBtn.disabled = true;
        return;
      }

      statusNotConfigured.classList.add('hidden');

      if (status.isAuthenticated) {
        statusReady.classList.remove('hidden');
        statusAuthRequired.classList.add('hidden');
        signInBtn.classList.add('hidden');
        saveCurrentBtn.classList.remove('hidden');
        signOutBtn.classList.remove('hidden');
        saveCurrentBtn.disabled = false;

        // Populate user bar
        const p = status.profile || {};
        const name = p.user_metadata?.full_name || p.user_metadata?.name || p.email || 'User';
        const email = p.email || '';
        const picture = p.user_metadata?.avatar_url || p.user_metadata?.picture;
        userName.textContent = name;
        userEmail.textContent = email;
        if (picture) {
          avatarImg.src = picture;
          avatarImg.classList.remove('hidden');
          avatarFallback.classList.add('hidden');
        } else {
          avatarImg.classList.add('hidden');
          avatarFallback.classList.remove('hidden');
          avatarFallback.textContent = (name?.[0] || 'U').toUpperCase();
        }
        userBar.classList.add('visible');
      } else {
        statusReady.classList.add('hidden');
        statusAuthRequired.classList.remove('hidden');
        signInBtn.classList.remove('hidden');
        saveCurrentBtn.classList.add('hidden');
        signOutBtn.classList.add('hidden');
        userBar.classList.remove('visible');
        saveCurrentBtn.disabled = true;
      }
    } catch (error) {
      console.error('Failed to check status:', error);
      statusReady.classList.add('hidden');
      statusNotConfigured.classList.remove('hidden');
      statusAuthRequired.classList.add('hidden');
      signInBtn.classList.add('hidden');
      saveCurrentBtn.classList.add('hidden');
      signOutBtn.classList.add('hidden');
      userBar.classList.remove('visible');
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

  async function signIn() {
    signInBtn.textContent = '⏳ Signing in...';
    signInBtn.disabled = true;
    const res = await new Promise((resolve) => {
      chrome.runtime.sendMessage({ action: 'sign-in' }, resolve);
    });
    if (res?.success) {
      await checkStatus();
    } else {
      console.error('Sign-in failed:', res?.error);
    }
    signInBtn.textContent = '🔑 Sign in with Google';
    signInBtn.disabled = false;
  }

  async function signOut() {
    signOutBtn.textContent = '⏳ Signing out...';
    signOutBtn.disabled = true;
    const res = await new Promise((resolve) => {
      chrome.runtime.sendMessage({ action: 'sign-out' }, resolve);
    });
    if (res?.success) {
      await checkStatus();
    }
    signOutBtn.textContent = '🚪 Sign out';
    signOutBtn.disabled = false;
  }
});
