import 'dart:ui';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_data_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedCountry = 'US';

  Future<void> _handleGoogleLogin(BuildContext context) async {
    final auth = AuthService();
    final success = await auth.loginWithGoogle(country: _selectedCountry);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'Google sign-in did not complete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await AppDataService().bootstrapAuthenticatedUser(forceRefresh: true);
    if (context.mounted && AppDataService().bootstrapErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppDataService().bootstrapErrorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tertiaryContainer.withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(
                color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.4),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Brand Logo ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/remitflow_logo.png',
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'RemitFlow',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.vaultGreen,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 80,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ── Top Section (Hero + Typography) ───────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Container(
                                      height: 180,
                                      width: 180,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.vaultGreen
                                                .withValues(alpha: 0.15),
                                            blurRadius: 40,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/images/login_hero_globe.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  Text(
                                    'Global Wealth,\nSeamlessly\nCurated.',
                                    style: GoogleFonts.newsreader(
                                      fontSize: 46,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.onSurface,
                                      letterSpacing: -1.5,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Experience the modern way to manage cross-border remittances. Beautiful, secure, and powered by Polygon.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),

                              // ── Bottom Section (Actions) ──────────────────
                              Column(
                                children: [
                                  const SizedBox(height: 48),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _CountryChip(
                                          flag: '🇺🇸',
                                          label: 'USA',
                                          isSelected: _selectedCountry == 'US',
                                          onTap: () => setState(
                                            () => _selectedCountry = 'US',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        _CountryChip(
                                          flag: '🇮🇳',
                                          label: 'India',
                                          isSelected: _selectedCountry == 'IN',
                                          onTap: () => setState(
                                            () => _selectedCountry = 'IN',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _handleGoogleLogin(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.surfaceContainerLowest,
                                        foregroundColor: AppTheme.onSurface,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        elevation: 0.5,
                                        side: BorderSide(
                                          color: AppTheme.outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            9999,
                                          ),
                                        ),
                                      ),
                                      icon: const FaIcon(
                                        FontAwesomeIcons.google,
                                        size: 20,
                                      ),
                                      label: Text(
                                        'Continue with Google',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (AuthService().lastError != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      AuthService().lastError!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.error,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'By continuing, you agree to our Terms of Service and Privacy Policy.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: AuthService(),
            builder: (context, _) {
              if (!AuthService().isLoading) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.vaultGreen,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.onSurface
                    : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
