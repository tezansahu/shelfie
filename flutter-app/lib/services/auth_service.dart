import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Authentication service for handling Google SSO with Supabase
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  
  AuthService._();
  
  SupabaseClient get _client => Supabase.instance.client;
  
  // Google Sign-In instance
  GoogleSignIn? _googleSignIn;
  
  /// Initialize Google Sign-In with the appropriate configuration
  void initializeGoogleSignIn({required String webClientId}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // For Android, use serverClientId (web client ID) to get ID tokens
      _googleSignIn = GoogleSignIn(
        scopes: ['openid', 'email', 'profile'],
        serverClientId: webClientId, // Use serverClientId for Android
      );
    } else {
      // For web, desktop, and iOS
      _googleSignIn = GoogleSignIn(
        scopes: ['openid', 'email', 'profile'],
        clientId: webClientId,
      );
    }
    
    debugPrint('✅ Google Sign-In initialized for $defaultTargetPlatform');
    debugPrint('   Client ID: $webClientId');
  }
  
  /// Get current user
  User? get currentUser => _client.auth.currentUser;
  
  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
  
  /// Get current user's ID
  String? get userId => currentUser?.id;
  
  /// Get current user's email
  String? get userEmail => currentUser?.email;
  
  /// Get current user's display name
  String? get userDisplayName => currentUser?.userMetadata?['full_name'] ?? 
                                 currentUser?.userMetadata?['name'];
  
  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  /// Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In not initialized. Call initializeGoogleSignIn first.');
      }

      // DEBUG: Print configuration
      debugPrint('🔍 Debug Info:');
      debugPrint('   Platform: $defaultTargetPlatform');
      debugPrint('   Google Sign-In configured: ${_googleSignIn != null}');
      debugPrint('   Scopes: ${_googleSignIn!.scopes}');
      debugPrint('   Client ID: ${_googleSignIn!.clientId}');
      debugPrint('   Package name should be: com.shelfie.shelfie');
      
      // Sign out from previous session to ensure clean state
      await _googleSignIn!.signOut();
      
      // Trigger Google Sign-In flow
      debugPrint('🔐 Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled by user');
      }

      debugPrint('✅ Google user selected: ${googleUser.email}');
      
      // Get Google authentication
      debugPrint('🔑 Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      debugPrint('🔍 Token debug:');
      debugPrint('   Access token available: ${googleAuth.accessToken != null}');
      debugPrint('   ID token available: ${googleAuth.idToken != null}');
      debugPrint('   Access token length: ${googleAuth.accessToken?.length ?? 0}');
      debugPrint('   ID token length: ${googleAuth.idToken?.length ?? 0}');
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('❌ Missing tokens:');
        debugPrint('   Access token: ${googleAuth.accessToken == null ? 'MISSING' : 'OK'}');
        debugPrint('   ID token: ${googleAuth.idToken == null ? 'MISSING' : 'OK'}');
        throw Exception('Failed to get Google authentication tokens');
      }

      debugPrint('✅ Got Google tokens, signing in to Supabase...');
      
      // Sign in to Supabase with Google credentials
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      
      if (response.user == null) {
        debugPrint('❌ Supabase auth failed: ${response.session}');
        throw Exception('Failed to authenticate with Supabase');
      }
      
      debugPrint('✅ Successfully signed in: ${response.user!.email}');
      
      // Migrate any orphaned items from pre-auth era to current user
      try {
        debugPrint('🔄 Migrating orphaned items to current user...');
        final itemsService = ItemsService();
        await itemsService.migrateOrphanedItemsToCurrentUser();
        debugPrint('✅ Item migration completed');
      } catch (migrationError) {
        debugPrint('⚠️ Item migration failed (non-critical): $migrationError');
        // Don't fail the sign-in process if migration fails
      }
      
      return response;
      
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      if (e.toString().contains('Failed to get Google authentication tokens')) {
        debugPrint('💡 This usually means:');
        debugPrint('   1. Google OAuth scopes are insufficient');
        debugPrint('   2. Google Play Services issue');
        debugPrint('   3. Network connectivity problem');
      }
      rethrow;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      
      // Sign out from Supabase
      await _client.auth.signOut();
      
      debugPrint('✅ Successfully signed out');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }
  
  /// Get user profile data from our users table
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isAuthenticated) return null;
    
    try {
      final response = await _client
          .from('users')
          .select('*')
          .eq('id', userId!)
          .single();
      
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return null;
    }
  }
  
  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    try {
      await _client
          .from('users')
          .update({
            'display_name': displayName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId!);
      
      debugPrint('✅ User profile updated');
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow;
    }
  }
  
  /// Refresh session to extend expiry
  Future<void> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      if (response.session != null) {
        debugPrint('✅ Session refreshed successfully');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing session: $e');
      rethrow;
    }
  }
  
  /// Auto-refresh session periodically (call this when app becomes active)
  Future<void> autoRefreshIfNeeded() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      // Refresh if session will expire within 24 hours
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      final now = DateTime.now();
      final timeUntilExpiry = expiryTime.difference(now);
      
      if (timeUntilExpiry.inHours < 24) {
        debugPrint('🔄 Auto-refreshing session (expires in ${timeUntilExpiry.inHours} hours)');
        await refreshSession();
      }
    }
  }
}
