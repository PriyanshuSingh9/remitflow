import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = AppDataService();

    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) {
        final dashboard = appData.dashboard;
        if (dashboard == null) {
          return const Scaffold(
            backgroundColor: AppTheme.surfaceContainerLowest,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.vaultGreen),
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: AppTheme.surfaceContainerLowest,
          bottomNavigationBar: const _BottomNavBar(),
          body: Stack(
            children: [
              const _GrainOverlay(),
              RefreshIndicator(
                color: AppTheme.vaultGreen,
                onRefresh: appData.refreshDashboard,
                child: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        _GreetingSection(user: dashboard.user),
                        const SizedBox(height: 24),
                        _BalanceHeroWithMesh(user: dashboard.user),
                        const SizedBox(height: 32),
                        _ExchangeRateTicker(exchangeRate: dashboard.exchangeRate),
                        if (appData.bootstrapErrorMessage != null) ...[
                          const SizedBox(height: 20),
                          _InlineError(message: appData.bootstrapErrorMessage!),
                        ],
                        const SizedBox(height: 40),
                        _RecentTransactions(transactions: dashboard.recentTransactions),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.error,
          ),
        ),
      ),
    );
  }
}

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

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final initial =
        user.preferredName.isNotEmpty ? user.preferredName[0].toUpperCase() : 'R';

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
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.surfaceContainer,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.vaultGreen,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            user.preferredName,
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _flagForCountry(user.country),
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeroWithMesh extends StatelessWidget {
  const _BalanceHeroWithMesh({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: screenWidth,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MeshBlobPainter(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have saved',
                style: GoogleFonts.newsreader(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      _formatUsd(user.lifetimeSavingsUsd),
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
                    'for a balance of',
                    style: GoogleFonts.newsreader(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatUsd(user.availableBalanceUsd),
                style: GoogleFonts.newsreader(
                  fontSize: 52,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.vaultGreen,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeshBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

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

    _drawBlob(
      canvas,
      center: Offset(cx + 40, cy - 30),
      radiusX: size.width * 0.28,
      radiusY: size.height * 0.30,
      colors: [
        const Color(0xFFD9F542).withValues(alpha: 0.20),
        const Color(0xFFE8F5A0).withValues(alpha: 0.10),
        const Color(0xFFD9F542).withValues(alpha: 0),
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

class _ExchangeRateTicker extends StatelessWidget {
  const _ExchangeRateTicker({required this.exchangeRate});

  final ExchangeRateData exchangeRate;

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
              '1 ${exchangeRate.baseCurrency}',
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
              '₹${exchangeRate.rate.toStringAsFixed(2)}',
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
                '${exchangeRate.cheaperPercentage.toStringAsFixed(1)}% cheaper',
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

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});

  final List<TransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
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
                '${transactions.length} LOADED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (transactions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No transactions yet. Your next transfer will appear here.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...transactions.map((transaction) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _TransactionItem(transaction: transaction),
                )),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  const _TransactionItem({required this.transaction});

  final TransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final gradientColors = transaction.isSent
        ? const [Color(0xFF8FB89A), Color(0xFF476556)]
        : const [Color(0xFF7A8FA6), Color(0xFF34495D)];

    return Row(
      children: [
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
                color: gradientColors.first.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            transaction.isSent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transaction.isSent ? 'Sent to' : 'Received from'} ${transaction.counterparty.preferredName}',
                style: GoogleFonts.newsreader(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, HH:mm').format(transaction.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${transaction.isSent ? '-' : '+'}${_formatUsd(transaction.amountUsd)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: transaction.isSent ? AppTheme.onSurface : AppTheme.vaultGreen,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _flagForCountry(transaction.counterparty.country),
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(width: 3),
                Text(
                  '₹${NumberFormat('#,##,##0.00').format(transaction.amountInr)}',
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

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceContainerLowest.withValues(alpha: 0),
            AppTheme.surfaceContainerLowest.withValues(alpha: 0.95),
            AppTheme.surfaceContainerLowest,
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: true,
            ),
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
            const _NavItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isActive: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final bool isActive;

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
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

String _formatUsd(double amount) {
  return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
}

String _flagForCountry(String countryCode) {
  switch (countryCode.toUpperCase()) {
    case 'IN':
      return '🇮🇳';
    case 'US':
      return '🇺🇸';
    default:
      return '🌍';
  }
}
