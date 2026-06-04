import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import 'onboarding_shell.dart';

class OnboardingAvatarScreen extends ConsumerStatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  ConsumerState<OnboardingAvatarScreen> createState() =>
      _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState
    extends ConsumerState<OnboardingAvatarScreen> {
  String? _avatarUrl;
  bool _uploading = false;
  bool _saving = false;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _parseColor(String hex) {
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
    if (_avatarUrl == null) {
      context.go('/onboarding/theme');
      return;
    }
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).updateProfile(avatarUrl: _avatarUrl);
    if (mounted) context.go('/onboarding/theme');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initials = _initials(user?.name ?? '');
    final profileColor =
        user?.color != null ? _parseColor(user!.color) : AppTheme.accent;

    return OnboardingShell(
      step: 6,
      totalSteps: 7,
      onBack: () => context.go('/onboarding/notifications'),
      illustration: AppImages.people(size: 72),
      illustrationHue: stickerHues[5],
      title: 'Add a profile photo',
      subtitle:
          'Put a face to your name so teammates can recognise you. You can always add one later.',
      buttonLabel: _avatarUrl != null ? 'Save & continue' : 'Skip for now',
      isLoading: _saving || _uploading,
      onContinue: (_saving || _uploading) ? null : _continue,
      child: Center(
        child: Column(
          children: [
            GestureDetector(
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
                        color: profileColor.withOpacity(0.25),
                        width: 2,
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
            ),
            const SizedBox(height: 14),
            Text(
              _uploading
                  ? 'Uploading…'
                  : _avatarUrl != null
                      ? 'Tap to change your photo'
                      : 'Tap to choose a photo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appColors.inkMuted,
              ),
            ),
            if (_avatarUrl != null) ...[
              const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}
