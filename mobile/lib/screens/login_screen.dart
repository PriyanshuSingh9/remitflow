import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // Background organic shapes
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.5),
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
                color: AppTheme.tertiaryContainer.withOpacity(0.4),
              ),
            ),
          ),
          // Glass blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(
                color: AppTheme.surfaceContainerLowest.withOpacity(0.4),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.vaultGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded, 
                      color: AppTheme.primaryContainer, 
                      size: 32
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Headline
                  Text(
                    'Global Wealth,\nSeamlessly\nCurated.',
                    style: GoogleFonts.newsreader(
                      fontSize: 48,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurface,
                      letterSpacing: -1.0,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Subtitle
                  Text(
                    'Experience the modern way to manage cross-border remittances. Beautiful, secure, and effortlessly fast.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Social Login Buttons
                  _buildSocialButton(
                    context: context,
                    iconWidget: const FaIcon(FontAwesomeIcons.google, size: 20),
                    label: 'Continue with Google',
                    onPressed: () => AuthService().loginWithGoogle(),
                  ),
                  const SizedBox(height: 16),
                  _buildSocialButton(
                    context: context,
                    iconWidget: const FaIcon(FontAwesomeIcons.apple, size: 20),
                    label: 'Continue with Apple',
                    onPressed: () {}, // To be implemented
                  ),
                  const SizedBox(height: 16),
                  _buildSocialButton(
                    context: context,
                    iconWidget: const Icon(Icons.email_outlined, size: 20),
                    label: 'Continue with Email',
                    onPressed: () {}, // To be implemented later (requires prompt for email)
                    isPrimary: true, // Use brand colors for email
                  ),
                  const SizedBox(height: 16),
                  
                  // Terms and conditions
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'By continuing, you agree to our Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Loading Overlay
          ListenableBuilder(
            listenable: AuthService(),
            builder: (context, _) {
              if (AuthService().isLoading) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.vaultGreen),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required Widget iconWidget,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.primaryContainer : AppTheme.surfaceContainerLowest,
          foregroundColor: isPrimary ? AppTheme.vaultGreen : AppTheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: isPrimary ? 0 : 0.5,
          side: isPrimary ? null : BorderSide(color: AppTheme.outlineVariant.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        icon: iconWidget,
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: isPrimary ? 1.0 : 0.5,
          ),
        ),
      ),
    );
  }
}
