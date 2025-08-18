import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Provider for the authentication service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

/// Provider for the current user
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) => state.session?.user);
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenData((user) => user != null).value ?? false;
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenData((user) => user?.id).value;
});

/// Provider for user profile data from our users table
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  
  if (!isAuthenticated) return null;
  
  return await authService.getUserProfile();
});

/// Authentication state notifier for managing auth operations
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._authService) : super(const AsyncValue.data(null));
  
  final AuthService _authService;
  
  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithGoogle();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({String? displayName}) async {
    state = const AsyncValue.loading();
    try {
      await _authService.updateUserProfile(displayName: displayName);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for the auth notifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
