import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/user_preferences.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/user_service.dart';
import '../theme/haychat_theme.dart';
import '../widgets/hay_widgets.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key, this.user});

  final AppUser? user;

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user?.displayName ?? '',
  );
  late final TextEditingController _status = TextEditingController(
    text: widget.user?.status ?? 'Hey there! I am using HayChat',
  );
  late Uint8List? _avatarBytes = widget.user?.avatarBytes;
  bool _avatarChanged = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refreshAvatar);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_refreshAvatar)
      ..dispose();
    _status.dispose();
    super.dispose();
  }

  void _refreshAvatar() => setState(() {});

  String get _initials => _initialsFor(_name.text);

  Future<void> _chooseAvatar() async {
    final bytes = await _pickProfileImage(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarChanged = true;
    });
  }

  void _removeAvatar() {
    setState(() {
      _avatarBytes = null;
      _avatarChanged = true;
    });
  }

  Future<void> _save() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await UserService.instance.completeProfile(
        displayName: _name.text,
        status: _status.text,
        avatarBytes: _avatarChanged ? _avatarBytes : null,
        removeAvatar: _avatarChanged && _avatarBytes == null,
      );
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      if (mounted) _notice(context, 'Could not save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              const HayTitle(
                'Create your profile',
                subtitle: 'This is how people will recognize you in HayChat.',
              ),
              const SizedBox(height: 28),
              Center(
                child: _ProfileAvatarEditor(
                  initials: _initials,
                  avatarBytes: _avatarBytes,
                  photoUrl: _avatarChanged ? '' : widget.user?.photoUrl ?? '',
                  onChoose: _loading ? null : _chooseAvatar,
                  onRemove:
                      !_loading &&
                          (_avatarBytes != null ||
                              (!_avatarChanged &&
                                  (widget.user?.photoUrl.isNotEmpty ?? false)))
                      ? _removeAvatar
                      : null,
                ),
              ),
              const SizedBox(height: 28),
              HayField(
                label: 'Display Name',
                controller: _name,
                hint: 'Your name',
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              HayField(
                label: 'About',
                controller: _status,
                hint: 'Tell people a little about you',
                textInputAction: TextInputAction.done,
                validator: _validateStatus,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              HayPrimaryButton(
                label: _loading ? 'Saving Profile...' : 'Continue to Chats',
                onPressed: _loading ? null : _save,
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _signOut,
                  child: const Text(
                    'Use a different account',
                    style: TextStyle(color: HayColors.muted, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.authUser, super.key});

  final User authUser;

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: StreamBuilder<AppUser?>(
        stream: UserService.instance.watchUser(authUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load your profile.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: HayColors.gold,
                strokeWidth: 2,
              ),
            );
          }
          return ListView(
            children: [
              const SizedBox(height: 18),
              Center(
                child: HayAvatar(
                  initials: user.initials,
                  size: 88,
                  online: user.isOnline,
                  imageBytes: user.avatarBytes,
                  photoUrl: user.photoUrl,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                user.status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              _MenuRow(
                icon: Icons.person_outline_rounded,
                title: 'Account',
                description: 'Edit photo, name, and about',
                onTap: () => _editProfile(context, user),
              ),
              _MenuRow(
                icon: Icons.qr_code_2_rounded,
                title: 'My QR Code',
                description: 'Let someone send you a contact invite',
                onTap: () => Navigator.pushNamed(context, HayRoutes.myQr),
              ),
              _MenuRow(
                icon: Icons.mark_email_read_outlined,
                title: 'Email Verification',
                description: authUser.emailVerified
                    ? 'Verified'
                    : 'Tap to resend verification email',
                onTap: () => _resendVerification(context),
              ),
              _MenuRow(
                icon: Icons.shield_outlined,
                title: 'Privacy',
                description: 'Online visibility and account security',
                onTap: () => Navigator.pushNamed(context, HayRoutes.settings),
              ),
              _MenuRow(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                description: 'Alerts, previews, and sounds',
                onTap: () => Navigator.pushNamed(context, HayRoutes.settings),
              ),
              _MenuRow(
                icon: Icons.wallpaper_outlined,
                title: 'Appearance',
                description: 'Brass & forest dark theme',
                onTap: () => Navigator.pushNamed(context, HayRoutes.settings),
              ),
              _MenuRow(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                destructive: true,
                onTap: () => _logOut(context),
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Back to chats'),
                style: TextButton.styleFrom(foregroundColor: HayColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: StreamBuilder<UserPreferences>(
        stream: PreferencesService.instance.watchCurrent(),
        initialData: const UserPreferences(),
        builder: (context, snapshot) {
          final preferences = snapshot.data ?? const UserPreferences();
          return ListView(
            children: [
              const HayBackButton(),
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Notifications'),
              _PreferenceSwitch(
                icon: Icons.notifications_active_outlined,
                title: 'Message alerts',
                description: 'Allow chat notification alerts',
                value: preferences.notificationsEnabled,
                onChanged: (value) => _savePreferences(
                  context,
                  preferences.copyWith(notificationsEnabled: value),
                ),
              ),
              _PreferenceSwitch(
                icon: Icons.preview_outlined,
                title: 'Message previews',
                description: 'Show message text in alerts',
                value:
                    preferences.notificationsEnabled &&
                    preferences.messagePreviews,
                onChanged: preferences.notificationsEnabled
                    ? (value) => _savePreferences(
                        context,
                        preferences.copyWith(messagePreviews: value),
                      )
                    : null,
              ),
              _PreferenceSwitch(
                icon: Icons.volume_up_outlined,
                title: 'Sounds',
                description: 'Play notification sounds',
                value:
                    preferences.notificationsEnabled &&
                    preferences.soundsEnabled,
                onChanged: preferences.notificationsEnabled
                    ? (value) => _savePreferences(
                        context,
                        preferences.copyWith(soundsEnabled: value),
                      )
                    : null,
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Privacy'),
              _PreferenceSwitch(
                icon: Icons.visibility_outlined,
                title: 'Show online status',
                description: 'Let other people see when you are online',
                value: preferences.showOnlineStatus,
                onChanged: (value) async {
                  final next = preferences.copyWith(showOnlineStatus: value);
                  await _savePreferences(context, next);
                  await AuthService.instance.setPresence(isOnline: value);
                },
              ),
              _MenuRow(
                icon: Icons.block_rounded,
                title: 'Blocked Users',
                description: 'No blocked users',
                onTap: () => _showInfo(
                  context,
                  title: 'Blocked Users',
                  message: 'You have not blocked anyone.',
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Account'),
              _MenuRow(
                icon: Icons.lock_reset_rounded,
                title: 'Password & Security',
                description: 'Send a password reset email',
                onTap: () => _sendPasswordReset(context),
              ),
              _MenuRow(
                icon: Icons.language_rounded,
                title: 'Language',
                description: 'English',
                onTap: () => _showInfo(
                  context,
                  title: 'Language',
                  message: 'HayChat currently uses English.',
                ),
              ),
              _MenuRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                description: 'Brass & forest dark theme',
                onTap: () => _showInfo(
                  context,
                  title: 'Appearance',
                  message:
                      'The brass & forest dark theme is selected. More themes can be added later.',
                ),
              ),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                description: 'Account and chat help',
                onTap: () => _showInfo(
                  context,
                  title: 'Help & Support',
                  message:
                      'For sign-in problems, reset your password or resend email verification. Chat data requires your Firestore connection.',
                ),
              ),
              _MenuRow(
                icon: Icons.info_outline_rounded,
                title: 'About HayChat',
                description: 'Version 1.0.0',
                onTap: () => _showInfo(
                  context,
                  title: 'About HayChat',
                  message:
                      'HayChat 1.0.0\nA warm, private messaging app built with Flutter and Firebase.',
                ),
              ),
              _MenuRow(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                destructive: true,
                onTap: () => _logOut(context),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAvatarEditor extends StatelessWidget {
  const _ProfileAvatarEditor({
    required this.initials,
    required this.avatarBytes,
    required this.photoUrl,
    required this.onChoose,
    required this.onRemove,
  });

  final String initials;
  final Uint8List? avatarBytes;
  final String photoUrl;
  final VoidCallback? onChoose;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            HayAvatar(
              initials: initials,
              size: 88,
              imageBytes: avatarBytes,
              photoUrl: photoUrl,
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: IconButton.filled(
                tooltip: 'Choose profile picture',
                onPressed: onChoose,
                style: IconButton.styleFrom(
                  backgroundColor: HayColors.gold,
                  foregroundColor: const Color(0xFF23180B),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
              ),
            ),
          ],
        ),
        if (onRemove != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onRemove, child: const Text('Remove photo')),
        ],
      ],
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});

  final AppUser user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user.displayName,
  );
  late final TextEditingController _status = TextEditingController(
    text: widget.user.status,
  );
  late Uint8List? _avatarBytes = widget.user.avatarBytes;
  bool _avatarChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_refresh)
      ..dispose();
    _status.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _chooseAvatar() async {
    final bytes = await _pickProfileImage(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarChanged = true;
    });
  }

  void _removeAvatar() {
    setState(() {
      _avatarBytes = null;
      _avatarChanged = true;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        displayName: _name.text,
        status: _status.text,
        avatarBytes: _avatarChanged ? _avatarBytes : null,
        removeAvatar: _avatarChanged && _avatarBytes == null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _notice(context, 'Could not update your profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        _avatarBytes != null ||
        (!_avatarChanged && widget.user.photoUrl.isNotEmpty);
    return AlertDialog(
      backgroundColor: HayColors.card,
      title: const Text(
        'Edit profile',
        style: TextStyle(fontFamily: HayTheme.displayFont),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileAvatarEditor(
                  initials: _initialsFor(_name.text),
                  avatarBytes: _avatarBytes,
                  photoUrl: _avatarChanged ? '' : widget.user.photoUrl,
                  onChoose: _saving ? null : _chooseAvatar,
                  onRemove: !_saving && hasPhoto ? _removeAvatar : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 40,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _status,
                  maxLength: 120,
                  minLines: 2,
                  maxLines: 3,
                  validator: _validateStatus,
                  decoration: const InputDecoration(labelText: 'About'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: HayColors.gold,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          secondary: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HayColors.elevated,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: HayColors.goldSoft),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: HayColors.ivory,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(color: HayColors.muted, fontSize: 10),
          ),
          activeThumbColor: HayColors.gold,
          value: value,
          onChanged: onChanged,
        ),
        const Hairline(),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.description,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? HayColors.clay : HayColors.goldSoft;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          onTap: onTap,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HayColors.elevated,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: destructive ? HayColors.clay : HayColors.ivory,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: description == null
              ? null
              : Text(
                  description!,
                  style: const TextStyle(color: HayColors.muted, fontSize: 10),
                ),
          trailing: destructive
              ? null
              : const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: HayColors.muted,
                ),
        ),
        const Hairline(),
      ],
    );
  }
}

Future<Uint8List?> _pickProfileImage(BuildContext context) async {
  try {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (bytes.length > UserService.maximumAvatarBytes) {
      if (context.mounted) {
        _notice(context, 'Choose a smaller photo (maximum 350 KB).');
      }
      return null;
    }
    return bytes;
  } catch (_) {
    if (context.mounted) {
      _notice(context, 'Could not open your photo library.');
    }
    return null;
  }
}

String _initialsFor(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'YOU';
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length.clamp(1, 2)).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String? _validateName(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2) return 'Enter at least 2 characters';
  if (length > 40) return 'Use 40 characters or fewer';
  return null;
}

String? _validateStatus(String? value) {
  final length = value?.trim().length ?? 0;
  if (length == 0) return 'Add a short status';
  if (length > 120) return 'Use 120 characters or fewer';
  return null;
}

Future<void> _editProfile(BuildContext context, AppUser user) async {
  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EditProfileDialog(user: user),
  );
  if (updated == true && context.mounted) {
    _notice(context, 'Profile updated.');
  }
}

Future<void> _savePreferences(
  BuildContext context,
  UserPreferences preferences,
) async {
  try {
    await PreferencesService.instance.save(preferences);
  } catch (_) {
    if (context.mounted) _notice(context, 'Could not save that setting.');
  }
}

Future<void> _resendVerification(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user?.emailVerified ?? false) {
    _notice(context, 'Your email is already verified.');
    return;
  }
  try {
    await AuthService.instance.resendEmailVerification();
    if (context.mounted) _notice(context, 'Verification email sent.');
  } catch (error) {
    if (context.mounted) {
      _notice(context, AuthService.instance.messageFor(error));
    }
  }
}

Future<void> _sendPasswordReset(BuildContext context) async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null || email.isEmpty) {
    _notice(context, 'This account does not have a password email.');
    return;
  }
  try {
    await AuthService.instance.sendPasswordReset(email);
    if (context.mounted) _notice(context, 'Password reset email sent.');
  } catch (error) {
    if (context.mounted) {
      _notice(context, AuthService.instance.messageFor(error));
    }
  }
}

void _showInfo(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: HayColors.card,
      title: Text(
        title,
        style: const TextStyle(fontFamily: HayTheme.displayFont),
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

void _notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _logOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: HayColors.card,
      title: const Text(
        'Log out?',
        style: TextStyle(fontFamily: HayTheme.displayFont),
      ),
      content: const Text('You can sign back in whenever you are ready.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Log Out', style: TextStyle(color: HayColors.clay)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await AuthService.instance.signOut();
  if (context.mounted) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
