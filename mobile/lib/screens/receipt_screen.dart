import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import 'send_money_screen.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.receipt});

  final TransferReceipt receipt;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  double _exchangeRate = 83.42;

  static final _dateFmt = DateFormat("MMMM d, yyyy 'at' h:mm a");
  static final _inrFmt = NumberFormat('#,##,##0.00');
  static final _usdFmt = NumberFormat('#,##0.00');

  late final String _toName;
  late final String _toEmail;
  late final String? _toPhotoUrl;
  late final String _fromName;
  late final String _fromEmail;
  late final String? _fromPhotoUrl;
  late final String _recipientInitial;
  late final String _senderInitial;

  @override
  void initState() {
    super.initState();
    _computeOnce();
    _fetchExchangeRate();
  }

  void _computeOnce() {
    final tx = widget.receipt.transaction;
    final currentUser = AppDataService().sessionUser;
    final counterparty = tx.counterparty;
    final isSent = tx.isSent;

    _toName = isSent
        ? counterparty.preferredName
        : currentUser?.preferredName ?? 'You';
    _toEmail = isSent ? counterparty.email : currentUser?.email ?? '';
    _toPhotoUrl = isSent ? counterparty.photoUrl : currentUser?.photoUrl;
    _fromName = isSent
        ? currentUser?.preferredName ?? 'You'
        : counterparty.preferredName;
    _fromEmail = isSent ? currentUser?.email ?? '' : counterparty.email;
    _fromPhotoUrl = isSent ? currentUser?.photoUrl : counterparty.photoUrl;

    _recipientInitial = _toName.isNotEmpty ? _toName[0].toUpperCase() : 'R';
    _senderInitial = _fromName.isNotEmpty ? _fromName[0].toUpperCase() : 'Y';
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

  void _payAgain(BuildContext context) {
    final counterparty = widget.receipt.transaction.counterparty;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendMoneyScreen(recipient: counterparty),
      ),
    );
  }

  void _shareReceipt(BuildContext context) {
    final tx = widget.receipt.transaction;
    final isSent = tx.isSent;

    final shareText = isSent
        ? 'Sent ₹${_inrFmt.format(tx.amountInr)} on ${_dateFmt.format(tx.createdAt)}\nRef: ${tx.txHash ?? tx.id}'
        : 'Received ₹${_inrFmt.format(tx.amountInr)} on ${_dateFmt.format(tx.createdAt)}\nRef: ${tx.txHash ?? tx.id}';

    Share.share(shareText, subject: 'RemitFlow Transaction Receipt');
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.receipt.transaction;
    final isSent = tx.isSent;

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
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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
                                  isSent
                                      ? 'Payment Successful'
                                      : 'Payment Received',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${_inrFmt.format(tx.amountInr)}',
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
                                  '\$${_usdFmt.format(tx.amountUsd)} · 1 USD = ₹${_exchangeRate.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _dateFmt.format(tx.createdAt),
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
                                  color: AppTheme.primaryContainer.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_rounded,
                                color: AppTheme.vaultGreen,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _dashedDivider(),
                      const SizedBox(height: 20),

                      // ── TO ────────────────────────────────
                      Text(
                        'To: $_toName',
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
                            photoUrl: _toPhotoUrl,
                            initial: _recipientInitial,
                            bgColor: AppTheme.secondaryContainer,
                            fgColor: AppTheme.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _toEmail,
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
                        'From: $_fromName',
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
                            photoUrl: _fromPhotoUrl,
                            initial: _senderInitial,
                            bgColor: AppTheme.primaryContainer,
                            fgColor: AppTheme.vaultGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fromEmail,
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

                      const SizedBox(height: 16),

                      // ── Transaction ID ─────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSent ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 14,
                              color: isSent
                                  ? AppTheme.error
                                  : AppTheme.vaultGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSent ? 'Sent' : 'Received',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSent
                                    ? AppTheme.error
                                    : AppTheme.vaultGreen,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ── Action buttons ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReceipt(context),
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isSent
                        ? ElevatedButton.icon(
                            onPressed: () => _payAgain(context),
                            icon: const Icon(Icons.send, size: 20),
                            label: const Text('Pay Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.vaultGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.vaultGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                ],
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
    if (photoUrl == null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fgColor,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: bgColor,
      backgroundImage: NetworkImage(photoUrl),
      child: const SizedBox.shrink(),
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
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                ),
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
