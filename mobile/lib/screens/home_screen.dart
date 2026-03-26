import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // ── Grain Texture Overlay ──────────────────────────────
          const _GrainOverlay(),

          // ── Main Scrollable Content ───────────────────────────
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // ── Header / Greeting ─────────────────────────
                  const _GreetingSection(),

                  const SizedBox(height: 64),

                  // ── Portfolio Balance Hero ────────────────────
                  const _BalanceHero(),

                  const SizedBox(height: 48),

                  // ── Exchange Rate Ticker ──────────────────────
                  const _ExchangeRateTicker(),

                  const SizedBox(height: 48),

                  // ── Recent Transactions ───────────────────────
                  const _RecentTransactions(),
                ],
              ),
            ),
          ),

          // ── Bottom Navigation Bar ─────────────────────────────
          const _BottomNavBar(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// GRAIN OVERLAY — Subtle noise texture for "Digital Atelier" soul
// ═══════════════════════════════════════════════════════════════════════

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GrainPainter(),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final Random _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.012);
    const step = 4.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if (_random.nextDouble() > 0.5) {
          canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════
// GREETING SECTION — Avatar + "Hello Martin" in Newsreader serif
// ═══════════════════════════════════════════════════════════════════════

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceContainer,
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida/ADBb0ujZGxMKC7TXq8QflzraSuQTWFLlyOLkQsAQUdLdj6ZO-jjPmYWIolHGsznK9TjNzSDK4LXLx9LVTstYQvz_G6QymVFo9bx5YERLXNGz7p6GzSq9hta17pQMx6wAHUbl1oVxl3x6eWDEd3HrRxOyxr1TrltWrqD_eD2Rj3NGrCkXKcaDb_jgBRbDR3lCwZHzuWtqEniZPrEbR13mDiGuuHLmLrSj9UR_fH7B5KS-Ie5Pa12C_kWrkU76gmKad78CxVa7wikXvIt0Bw',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Greeting
          Text(
            'Hello Martin',
            style: GoogleFonts.newsreader(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
            ),
          ),

          const Spacer(),

          // Country flag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇺🇸', style: TextStyle(fontSize: 16)),
                SizedBox(width: 4),
                Text('USD', style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BALANCE HERO — Large serif balance + "Available Balance" subtitle
// ═══════════════════════════════════════════════════════════════════════

class _BalanceHero extends StatelessWidget {
  const _BalanceHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Big Balance
        Text(
          '\$2,450.00',
          style: GoogleFonts.newsreader(
            fontSize: 56,
            fontWeight: FontWeight.w400,
            color: AppTheme.vaultGreen,
            letterSpacing: -1.5,
            height: 1.0,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Available Balance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// EXCHANGE RATE TICKER — Live USD/INR rate
// ═══════════════════════════════════════════════════════════════════════

class _ExchangeRateTicker extends StatelessWidget {
  const _ExchangeRateTicker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🇺🇸', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '1 USD',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.sync_alt_rounded, size: 16, color: AppTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '₹83.42',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.vaultGreen,
              ),
            ),
            const SizedBox(width: 6),
            const Text('🇮🇳', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '2.3% cheaper',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RECENT TRANSACTIONS — Remittance-specific transactions
// ═══════════════════════════════════════════════════════════════════════

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Recent Transaction',
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                'VIEW ALL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Transaction 1 — Sent to India
          _TransactionItem(
            icon: Icons.arrow_upward_rounded,
            gradientColors: const [Color(0xFF8FB89A), Color(0xFF476556)],
            title: 'Sent to Priya Sharma',
            subtitle: 'Mar 23, 14:30',
            amount: '-\$500.00',
            amountColor: AppTheme.onSurface,
            secondaryAmount: '₹41,710.00',
            flag: '🇮🇳',
          ),

          const SizedBox(height: 24),

          // Transaction 2 — Received from US
          _TransactionItem(
            icon: Icons.arrow_downward_rounded,
            gradientColors: const [Color(0xFF7A8FA6), Color(0xFF34495D)],
            title: 'Received from John Davis',
            subtitle: 'Mar 21, 09:15',
            amount: '+\$1,200.00',
            amountColor: AppTheme.vaultGreen,
            secondaryAmount: '₹1,00,104.00',
            flag: '🇺🇸',
          ),

          const SizedBox(height: 24),

          // Transaction 3 — Sent to India
          _TransactionItem(
            icon: Icons.arrow_upward_rounded,
            gradientColors: const [Color(0xFF8FB89A), Color(0xFF476556)],
            title: 'Sent to Rahul Verma',
            subtitle: 'Mar 18, 20:45',
            amount: '-\$250.00',
            amountColor: AppTheme.onSurface,
            secondaryAmount: '₹20,855.00',
            flag: '🇮🇳',
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final String secondaryAmount;
  final String flag;

  const _TransactionItem({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.secondaryAmount,
    required this.flag,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Gradient circle icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),

        const SizedBox(width: 16),

        // Title + Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.newsreader(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Amount + INR equivalent
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flag,
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(width: 3),
                Text(
                  secondaryAmount,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION BAR — Floating glassmorphism with Transfer pill
// ═══════════════════════════════════════════════════════════════════════

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.85),
          // Glassmorphism backdrop — no borders (Digital Atelier "No-Line" rule)
        ),
        child: ClipRect(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home (Active)
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: true,
              ),

              // Transfer — Signature lime green pill
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_rounded, size: 18, color: Color(0xFF1A1C1C)),
                      const SizedBox(width: 8),
                      Text(
                        'TRANSFER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1C1C),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Settings
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isActive: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppTheme.onSurface
        : AppTheme.onSurface.withValues(alpha: 0.35);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
