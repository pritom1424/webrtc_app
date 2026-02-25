import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/profile/model/profile_state.dart';
import 'package:webrtc_app/features/profile/provider/profile_notifier.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _loginIdController = TextEditingController();
  bool _editingName = false;
  bool _editingLoginId = false;

  @override
  void dispose() {
    _nameController.dispose();
    _loginIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    // Show snackbar on success or error
    ref.listen<ProfileState>(profileProvider, (previous, next) {
      if (next.status == ProfileStatus.success &&
          next.successMessage != null &&
          next.successMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _editingName = false;
          _editingLoginId = false;
        });
        ref.read(profileProvider.notifier).clearMessages();
      }
      if (next.status == ProfileStatus.error &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(profileProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: profileState.isLoading && profileState.user == null
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                        )
                      : _buildContent(context, profileState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          /* IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ), */
          const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileState profileState) {
    final user = profileState.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── Avatar ────────────────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            user?.name ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user?.loginId ?? ''}',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
          ),

          const SizedBox(height: 32),

          // ── Profile Fields ────────────────────────────────────────────
          _buildSectionLabel('Account Info'),
          const SizedBox(height: 12),

          // Name field
          _buildEditableField(
            label: 'Display Name',
            value: user?.name ?? '',
            icon: Icons.person_outline_rounded,
            isEditing: _editingName,
            controller: _nameController,
            isLoading: profileState.isLoading,
            onEditTap: () {
              setState(() {
                _editingName = true;
                _editingLoginId = false;
                _nameController.text = user?.name ?? '';
              });
            },
            onSave: () {
              ref
                  .read(profileProvider.notifier)
                  .updateName(_nameController.text);
            },
            onCancel: () {
              setState(() => _editingName = false);
            },
          ),

          const SizedBox(height: 12),

          // Login ID field
          _buildEditableField(
            label: 'Login ID',
            value: user?.loginId ?? '',
            icon: Icons.badge_outlined,
            isEditing: _editingLoginId,
            controller: _loginIdController,
            isLoading: profileState.isLoading,
            onEditTap: () {
              setState(() {
                _editingLoginId = true;
                _editingName = false;
                _loginIdController.text = user?.loginId ?? '';
              });
            },
            onSave: () {
              ref
                  .read(profileProvider.notifier)
                  .updateLoginId(_loginIdController.text);
            },
            onCancel: () {
              setState(() => _editingLoginId = false);
            },
          ),

          const SizedBox(height: 24),

          // ── Account Info (read-only) ──────────────────────────────────
          _buildSectionLabel('App Info'),
          const SizedBox(height: 12),

          _buildReadOnlyField(
            label: 'User ID',
            value: user?.id ?? '',
            icon: Icons.fingerprint_rounded,
          ),

          const SizedBox(height: 32),

          // ── Sign Out ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textGrey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required IconData icon,
    required bool isEditing,
    required TextEditingController controller,
    required bool isLoading,
    required VoidCallback onEditTap,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? AppColors.primaryBlue : Colors.grey.shade200,
          width: isEditing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            title: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            subtitle: isEditing
                ? TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
            trailing: isEditing
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    onPressed: onEditTap,
                  ),
          ),
          if (isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textGrey, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textGrey,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
