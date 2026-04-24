import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.receipt});

  final TransferReceipt receipt;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  double _exchangeRate = 83.42;

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
  }

  Future<void> _fetchExchangeRate() async {
    final rate = await ExchangeRateService.getExchangeRate(
      baseCurrency: 'USD',
      targetCurrency: 'INR',
    );
    if (mounted && rate != null) {
      setState(() => _exchangeRate = rate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.receipt.transaction;
    final sender = AppDataService().sessionUser;
    final counterparty = tx.counterparty;

    final dateFmt = DateFormat("MMMM d, yyyy 'at' h:mm a");
    final inrFmt = NumberFormat('#,##,##0.00');
    final usdFmt = NumberFormat('#,##0.00');

    // Build initials for avatars
    final recipientInitial = counterparty.preferredName.isNotEmpty
        ? counterparty.preferredName[0].toUpperCase()
        : 'R';
    final senderInitial = (sender?.preferredName ?? 'Y').isNotEmpty
        ? (sender?.preferredName ?? 'Y')[0].toUpperCase()
        : 'Y';

    return Scaffold(
      backgroundColor: AppTheme.vaultGreen,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ),

            // ── Receipt ticket ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipPath(
                clipper: TicketClipper(),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          // ── Header: Amount + Check ────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment Successful',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${inrFmt.format(tx.amountInr)}',
                                      style: GoogleFonts.newsreader(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.onSurface,
                                        letterSpacing: -1.5,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '\$${usdFmt.format(tx.amountUsd)} · 1 USD = ₹${_exchangeRate.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      dateFmt.format(tx.createdAt),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppTheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryContainer.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.check_rounded, color: AppTheme.vaultGreen, size: 28),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          _dashedDivider(),
                          const SizedBox(height: 20),

                          // ── TO ────────────────────────────────
                          Text(
                            'To: ${counterparty.preferredName}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _userAvatar(
                                photoUrl: counterparty.photoUrl,
                                initial: recipientInitial,
                                bgColor: AppTheme.secondaryContainer,
                                fgColor: AppTheme.secondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  counterparty.email,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          _dashedDivider(),
                          const SizedBox(height: 20),

                          // ── FROM ──────────────────────────────
                          Text(
                            'From: ${sender?.preferredName ?? 'You'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _userAvatar(
                                photoUrl: sender?.photoUrl,
                                initial: senderInitial,
                                bgColor: AppTheme.primaryContainer,
                                fgColor: AppTheme.vaultGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sender?.email ?? 'user@remit.flow',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Reference ID ──────────────────────
                          Center(
                            child: Text(
                              'Ref: ${tx.txHash ?? tx.id}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.outline,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Bottom banner ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.vaultGreen, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Get assured cashback on global spends',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.vaultGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Circular avatar with photo or initial fallback.
  Widget _userAvatar({
    required String? photoUrl,
    required String initial,
    required Color bgColor,
    required Color fgColor,
  }) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: bgColor,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fgColor,
              ),
            )
          : null,
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            );
          }),
        );
      },
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 12);

    int zigZags = 30;
    double zigZagWidth = size.width / zigZags;
    for (int i = 0; i < zigZags; i++) {
      path.lineTo(zigZagWidth * i + zigZagWidth / 2, size.height);
      path.lineTo(zigZagWidth * (i + 1), size.height - 12);
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
