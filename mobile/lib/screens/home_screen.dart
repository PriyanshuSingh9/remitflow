import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'transfer_screen.dart';
import 'settings_screen.dart';
import '../services/auth_service.dart';
import '../services/neon_service.dart';
import '../services/exchange_rate_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      bottomNavigationBar: const _BottomNavBar(),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // ── Header / Greeting ─────────────────────────
                  const _GreetingSection(),

                  const SizedBox(height: 12),

                  // ── Balance Hero with Gradient Mesh ───────────
                  const _BalanceHeroWithMesh(),

                  const SizedBox(height: 32),

                  // ── Exchange Rate Ticker ──────────────────────
                  const _ExchangeRateTicker(),

                  const SizedBox(height: 40),

                  // ── Recent Transactions ───────────────────────
                  const _RecentTransactions(),
                ],
              ),
            ),
          ),
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
// GREETING SECTION — Centered "Hello [avatar] Martin" (matching ref)
// ═══════════════════════════════════════════════════════════════════════

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    final fullName = AuthService().userName ?? 'Martin';
    final firstName = fullName.split(' ').first;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hello',
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
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
          const SizedBox(width: 8),
          Text(
            firstName,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BALANCE HERO WITH MESH — Gradient blob + "You have saved" + balance
// ═══════════════════════════════════════════════════════════════════════

class _BalanceHeroWithMesh extends StatefulWidget {
  const _BalanceHeroWithMesh();

  @override
  State<_BalanceHeroWithMesh> createState() => _BalanceHeroWithMeshState();
}

class _BalanceHeroWithMeshState extends State<_BalanceHeroWithMesh> {
  double _balance = 2450.00;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    final email = AuthService().userEmail;
    if (email != null) {
      final amount = await NeonService().getAmountTransferred(email);
      if (mounted) {
        setState(() {
          _balance = amount;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate simulated savings based on transfer amount
    final savings = _balance * 0.023; // 2.3% saved
    
    // Format amounts
    final balanceStr = '\$ ${_balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    final savingsStr = '\$${savings.toStringAsFixed(2)}';
    
    return SizedBox(
      width: screenWidth,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Gradient Mesh Blob ─────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _MeshBlobPainter(),
            ),
          ),

          // ── Text Content over the mesh ────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "You have saved" context text
              Text(
                'You have saved',
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 6),

              // Earned badge + "on transfers" row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lime green pill with saved amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1C1C)))
                      : Text(
                          savingsStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1C1C),
                          ),
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '→',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'on a transfer of',
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Big Balance
              _isLoading 
                 ? const CircularProgressIndicator(color: AppTheme.vaultGreen)
                 : Text(
                    balanceStr,
                    style: GoogleFonts.newsreader(
                      fontSize: 52,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.vaultGreen,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MESH BLOB PAINTER — Organic gradient shapes (green/lime/blue)
// ═══════════════════════════════════════════════════════════════════════

class _MeshBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Large green/lime blob (center-right) ─────────────────────
    _drawBlob(
      canvas,
      center: Offset(cx + 20, cy + 20),
      radiusX: size.width * 0.42,
      radiusY: size.height * 0.52,
      colors: [
        const Color(0xFFD9F542).withValues(alpha: 0.35),
        const Color(0xFF8FB89A).withValues(alpha: 0.25),
        const Color(0xFFD9F542).withValues(alpha: 0.08),
      ],
    );

    // ── Dark blue-green blob (center-left, lower) ────────────────
    _drawBlob(
      canvas,
      center: Offset(cx - 30, cy + 40),
      radiusX: size.width * 0.30,
      radiusY: size.height * 0.38,
      colors: [
        const Color(0xFF34495D).withValues(alpha: 0.30),
        const Color(0xFF476556).withValues(alpha: 0.20),
        const Color(0xFF34495D).withValues(alpha: 0.05),
      ],
    );

    // ── Soft lime highlight (top-center) ─────────────────────────
    _drawBlob(
      canvas,
      center: Offset(cx + 40, cy - 30),
      radiusX: size.width * 0.28,
      radiusY: size.height * 0.30,
      colors: [
        const Color(0xFFD9F542).withValues(alpha: 0.20),
        const Color(0xFFE8F5A0).withValues(alpha: 0.10),
        const Color(0xFFD9F542).withValues(alpha: 0.0),
      ],
    );
  }

  void _drawBlob(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required List<Color> colors,
  }) {
    final rect = Rect.fromCenter(
      center: center,
      width: radiusX * 2,
      height: radiusY * 2,
    );
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radiusX,
        colors,
        [0.0, 0.5, 1.0],
        TileMode.clamp,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════
// EXCHANGE RATE TICKER — Live USD/INR rate
// ═══════════════════════════════════════════════════════════════════════

class _ExchangeRateTicker extends StatefulWidget {
  const _ExchangeRateTicker();

  @override
  State<_ExchangeRateTicker> createState() => _ExchangeRateTickerState();
}

class _ExchangeRateTickerState extends State<_ExchangeRateTicker> {
  double _exchangeRate = 83.42;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
  }

  Future<void> _fetchExchangeRate() async {
    final rate = await ExchangeRateService.getExchangeRate(baseCurrency: 'USD', targetCurrency: 'INR');
    if (mounted) {
      setState(() {
        if (rate != null) {
          _exchangeRate = rate;
        }
        _isLoading = false;
      });
    }
  }

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
            _isLoading
                ? const SizedBox(
                    width: 12, 
                    height: 12, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.vaultGreen)
                  )
                : Text(
                    '₹${_exchangeRate.toStringAsFixed(2)}',
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                'Recent Transactions',
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
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
          const _TransactionItem(
            icon: Icons.arrow_upward_rounded,
            gradientColors: [Color(0xFF8FB89A), Color(0xFF476556)],
            title: 'Sent to Priya Sharma',
            subtitle: 'Mar 23, 14:30',
            amount: '-\$500.00',
            amountColor: AppTheme.onSurface,
            secondaryAmount: '₹41,710.00',
            flag: '🇮🇳',
          ),

          const SizedBox(height: 20),

          // Transaction 2 — Received from US
          const _TransactionItem(
            icon: Icons.arrow_downward_rounded,
            gradientColors: [Color(0xFF7A8FA6), Color(0xFF34495D)],
            title: 'Received from John Davis',
            subtitle: 'Mar 21, 09:15',
            amount: '+\$1,200.00',
            amountColor: AppTheme.vaultGreen,
            secondaryAmount: '₹1,00,104.00',
            flag: '🇺🇸',
          ),

          const SizedBox(height: 20),

          // Transaction 3 — Sent to India
          const _TransactionItem(
            icon: Icons.arrow_upward_rounded,
            gradientColors: [Color(0xFF8FB89A), Color(0xFF476556)],
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
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
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
    return Container(
      padding: const EdgeInsets.only(
        left: 32,
        right: 32,
        top: 32,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceContainerLowest.withValues(alpha: 0.0),
            AppTheme.surfaceContainerLowest.withValues(alpha: 0.95),
            AppTheme.surfaceContainerLowest,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Home (Active)
            const _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: true,
            ),

            // Transfer — Signature lime green pill
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransferScreen()),
                );
              },
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isActive: false,
              ),
            ),
          ],
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
