import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // App theme colors to match main app
  static const Color _primaryColor = Color(0xFF596BFB);
  static const Color _primaryVariant = Color(0xFF4A5EE8);
  static const Color _accentColor = Color(0xFFE8EAFF);
  static const Color _surfaceColor = Color(0xFFF8F9FF);

  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService.instance.getUserProfile();
      if (mounted) {
        setState(() {
          userProfile = profile;
          _displayNameController.text = profile?['display_name'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Failed to load profile: $e');
      }
    }
  }

  Future<void> _updateDisplayName() async {
    if (_displayNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Display name cannot be empty');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
        displayName: _displayNameController.text.trim(),
      );
      
      _showSuccessSnackBar('Profile updated successfully');
      await _loadUserProfile(); // Reload profile
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await _showSignOutDialog();
    if (shouldSignOut != true) return;

    try {
      // Navigate away from profile before signing out to prevent UI issues
      if (mounted) {
        Navigator.of(context).pop(); // Go back to previous screen
      }
      
      // Small delay to allow navigation to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      await ref.read(authNotifierProvider.notifier).signOut();
      
    } catch (e) {
      _showErrorSnackBar('Failed to sign out: $e');
    }
  }

  Future<bool?> _showSignOutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _primaryColor,
        ),
      );
    }
  }

  // Helper method to safely get user email
  String _getUserEmail(dynamic user) {
    if (user == null) return 'Not available';
    
    // Try different possible locations for email
    return user.email ?? 
           user.user?.email ?? 
           (user is Map ? (user['email'] ?? user['user']?['email']) : null) ?? 
           'Not available';
  }

  // Helper method to safely get user display name from metadata
  String _getUserDisplayName(dynamic user) {
    if (user == null) return 'No display name';
    
    // Try different possible locations for display name
    final metadata = user.userMetadata ?? user.user?.userMetadata ?? user['user_metadata'] ?? {};
    
    return metadata['full_name'] ?? 
           metadata['name'] ?? 
           metadata['display_name'] ??
           userProfile?['display_name'] ??
           'No display name';
  }

  @override
  Widget build(BuildContext context) {
    // Use the correct providers from auth_provider.dart
    final userAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading user data: $error'),
              ),
              data: (user) => SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primaryColor,
                            _primaryVariant,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Profile Avatar
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              _getInitials(_getUserDisplayName(user)),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // User Email
                          Text(
                            _getUserEmail(user),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User Display Name
                          Text(
                            _getUserDisplayName(user),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Profile Information Section
                    _buildSection(
                      title: 'Account Information',
                      children: [
                        _buildInfoTile(
                          icon: Icons.email,
                          label: 'Email',
                          value: _getUserEmail(user),
                        ),
                        _buildInfoTile(
                          icon: Icons.calendar_today,
                          label: 'Member Since',
                          value: userProfile?['created_at'] != null
                              ? _formatDate(userProfile!['created_at'])
                              : (user?.createdAt != null ? _formatDate(user!.createdAt) : 'Not available'),
                        ),
                        _buildInfoTile(
                          icon: Icons.update,
                          label: 'Last Updated',
                          value: userProfile?['updated_at'] != null
                              ? _formatDate(userProfile!['updated_at'])
                              : 'Not available',
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Edit Profile Section
                    _buildSection(
                      title: 'Edit Profile',
                      children: [
                        TextField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            hintText: 'Enter your display name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateDisplayName,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Update Profile'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign Out Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can always sign back in later',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _signOut,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'No display name' || name == 'Not available') {
      return 'U';
    }
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}