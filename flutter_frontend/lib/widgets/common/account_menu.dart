import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firebase_service.dart';
import '../../firebase/settings_service.dart';
import '../../screens/login_screen.dart';
import 'glass_card.dart';

/// Account management widget that can be integrated into the dashboard or settings screen
class AccountMenu extends StatefulWidget {
  const AccountMenu({super.key});

  @override
  State<AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<AccountMenu> {
  final AuthService _authService = AuthService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  bool _isLoading = false;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _updateSyncStatus();
    
    // Listen for auth state changes
    _authService.authStateChanges.listen((_) {
      if (mounted) {
        _updateSyncStatus();
      }
    });
  }

  void _updateSyncStatus() {
    setState(() {
      if (_authService.currentUser != null && !_authService.isAnonymous()) {
        _syncStatus = 'Syncing across devices';
      } else if (_authService.isAnonymous()) {
        _syncStatus = 'Local storage only';
      } else {
        _syncStatus = 'Offline mode';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.getCurrentUserInfo();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildUserInfo(theme, user),
            const SizedBox(height: 16),
            _buildSyncStatus(theme),
            const SizedBox(height: 16),
            _buildActions(theme, user),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.account_circle_rounded,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          'Account',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(ThemeData theme, Map<String, dynamic>? user) {
    if (user == null) {
      return _buildOfflineInfo(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user['isAnonymous'] == true)
          _buildAnonymousInfo(theme)
        else
          _buildAuthenticatedInfo(theme, user),
      ],
    );
  }

  Widget _buildOfflineInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.offline_bolt_rounded,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Mode',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Settings stored locally only',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Create account to sync across devices',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedInfo(ThemeData theme, Map<String, dynamic> user) {
    final email = user['email'] as String?;
    final emailVerified = user['emailVerified'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                emailVerified ? Icons.verified_user_rounded : Icons.email_outlined,
                color: emailVerified ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email ?? 'Authenticated User',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      emailVerified ? 'Email verified' : 'Email not verified',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: emailVerified ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!emailVerified) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : _handleResendVerification,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Resend verification email',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatus(ThemeData theme) {
    return Row(
      children: [
        Icon(
          _getSyncIcon(),
          color: _getSyncColor(),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          _syncStatus ?? 'Unknown status',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  IconData _getSyncIcon() {
    if (_authService.currentUser != null && !_authService.isAnonymous()) {
      return Icons.sync_rounded;
    } else if (_authService.isAnonymous()) {
      return Icons.storage_rounded;
    } else {
      return Icons.sync_disabled_rounded;
    }
  }

  Color _getSyncColor() {
    if (_authService.currentUser != null && !_authService.isAnonymous()) {
      return Colors.green;
    } else if (_authService.isAnonymous()) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildActions(ThemeData theme, Map<String, dynamic>? user) {
    if (user == null) {
      // Offline mode - show sign in option
      return _buildSignInButton(theme);
    }

    if (user['isAnonymous'] == true) {
      // Anonymous user - show upgrade option
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUpgradeAccountButton(theme),
          const SizedBox(height: 8),
          _buildSignOutButton(theme),
        ],
      );
    }

    // Authenticated user - show account management options
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChangePasswordButton(theme),
        const SizedBox(height: 8),
        _buildSignOutButton(theme),
        const SizedBox(height: 8),
        _buildDeleteAccountButton(theme),
      ],
    );
  }

  Widget _buildSignInButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleSignIn,
      icon: const Icon(Icons.login_rounded, size: 18),
      label: const Text('Sign In'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildUpgradeAccountButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleUpgradeAccount,
      icon: const Icon(Icons.upgrade_rounded, size: 18),
      label: const Text('Create Account'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildChangePasswordButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleChangePassword,
      icon: const Icon(Icons.lock_outline_rounded, size: 18),
      label: const Text('Change Password'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(ThemeData theme) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleSignOut,
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Sign Out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(ThemeData theme) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _handleDeleteAccount,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: const Text('Delete Account'),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
      ),
    );
  }

  Future<void> _handleSignIn() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Future<void> _handleUpgradeAccount() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Future<void> _handleResendVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendEmailVerification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final result = await _showPasswordChangeDialog();
    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First reauthenticate
      final user = _authService.getCurrentUserInfo();
      final email = user?['email'] as String?;
      if (email == null) throw Exception('Email not available');

      final currentPassword = result['currentPassword'] as String;
      final newPassword = result['newPassword'] as String;

      await _authService.reauthenticateWithEmailAndPassword(email, currentPassword);
      
      // Then update password
      await _authService.updatePassword(newPassword);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await _showConfirmationDialog(
      'Sign Out',
      'Are you sure you want to sign out? Your settings will be saved.',
      'Sign Out',
      Colors.orange,
    );
    
    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await _showConfirmationDialog(
      'Delete Account',
      'This will permanently delete your account and all associated data. This action cannot be undone.',
      'Delete Account',
      Colors.red,
    );
    
    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.deleteAccount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String message,
    String confirmText,
    Color confirmColor,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<Map<String, String>?> _showPasswordChangeDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a new password';
                  }
                  final validation = _authService.validatePassword(value!);
                  if (!(validation['isValid'] as bool)) {
                    final errors = validation['errors'] as List<String>;
                    return errors.first;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'currentPassword': currentPasswordController.text,
                  'newPassword': newPasswordController.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    return result;
  }
}