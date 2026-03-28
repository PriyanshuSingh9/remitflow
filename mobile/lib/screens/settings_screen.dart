import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
        title: Text(
          'Settings',
          style: GoogleFonts.newsreader(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppTheme.onSurface),
            title: Text('Profile', style: GoogleFonts.plusJakartaSans(color: AppTheme.onSurface)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_rounded, color: AppTheme.onSurface),
            title: Text('Notifications', style: GoogleFonts.plusJakartaSans(color: AppTheme.onSurface)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security_rounded, color: AppTheme.onSurface),
            title: Text('Security', style: GoogleFonts.plusJakartaSans(color: AppTheme.onSurface)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text('Logout', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
