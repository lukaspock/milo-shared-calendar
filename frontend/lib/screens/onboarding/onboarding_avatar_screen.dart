import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'onboarding_shell.dart';

const _avatarColors = [
  '#6C63FF', '#FF6584', '#43B89C', '#F5A623',
  '#4A90E2', '#E74C3C', '#2ECC71', '#9B59B6',
];

class OnboardingAvatarScreen extends ConsumerStatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  ConsumerState<OnboardingAvatarScreen> createState() =>
      _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState
    extends ConsumerState<OnboardingAvatarScreen> {
  String? _avatarUrl;
  late String _selectedColor;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _selectedColor = user?.color ?? _avatarColors[0];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _toColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.accent;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await ApiService().uploadAvatarToCloudinary(File(picked.path));
      if (mounted) setState(() { _uploading = false; _avatarUrl = url; });
    } on CloudinaryUploadException catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.message}')),
        );
      }
    }
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    final user = ref.read(authProvider).user;
    final colorChanged = _selectedColor != user?.color;
    final hasPhoto = _avatarUrl != null;
    if (hasPhoto || colorChanged) {
      await ref.read(authProvider.notifier).updateProfile(
        color: colorChanged ? _selectedColor : null,
        avatarUrl: hasPhoto ? _avatarUrl : null,
      );
    }
    if (mounted) context.go('/onboarding/theme');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initials = _initials(user?.name ?? '');
    final profileColor = _toColor(_selectedColor);

    final avatarHeader = GestureDetector(
      onTap: _uploading ? null : _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: _avatarUrl != null
                  ? Colors.transparent
                  : profileColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: profileColor.withOpacity(0.30),
                width: 2.5,
              ),
            ),
            child: _avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      _avatarUrl!,
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: profileColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : _uploading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: profileColor, strokeWidth: 2.5))
                    : Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: profileColor,
                          ),
                        ),
                      ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.appColors.bg,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return OnboardingShell(
      step: 6,
      totalSteps: 7,
      onBack: () => context.go('/onboarding/notifications'),
      customHeader: avatarHeader,
      title: 'Make it yours',
      subtitle:
          'Pick a colour and add a photo so your friends know it\'s you. You can always change it later.',
      buttonLabel: (_avatarUrl != null || _selectedColor != user?.color)
          ? 'Save & continue'
          : 'Skip for now',
      isLoading: _saving || _uploading,
      onContinue: (_saving || _uploading) ? null : _continue,
      child: Column(
        children: [
          // Photo hint / remove
          Text(
            _uploading
                ? 'Uploading…'
                : _avatarUrl != null
                    ? 'Tap to change your photo'
                    : 'Tap to add a photo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appColors.inkMuted,
            ),
          ),
          if (_avatarUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _avatarUrl = null),
              child: Text(
                'Remove photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.danger,
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Color label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'YOUR COLOUR',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.appColors.inkMuted,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Color swatches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _avatarColors.map((hex) {
              final c = _toColor(hex);
              final selected = hex == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? context.appColors.ink
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
