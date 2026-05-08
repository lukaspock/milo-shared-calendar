import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _focused ? AppTheme.ink : AppTheme.inkMuted,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused ? AppTheme.ink : AppTheme.line,
                width: 1.5,
              ),
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.ink,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              validator: widget.validator,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.inkMuted,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon, color: AppTheme.inkMuted, size: 18)
                    : null,
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                errorStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.danger, fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
