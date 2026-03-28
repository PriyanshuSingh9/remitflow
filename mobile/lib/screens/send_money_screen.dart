import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';

/// Step 2 of the transfer flow — enter USD amount, see INR conversion + fees,
/// then confirm and send. No wallet balance shown — we debit the user's bank.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key, required this.recipient});

  final RecipientSummary recipient;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '',
  );

  double _exchangeRate = 83.42; // fallback
  bool _rateLoading = true;
  bool _isLiveRate = false;

  // ── Fee model (same as home_screen: deterministic SWIFT comparison) ──
  static const double _remitflowFeeFrac = 0.002; // 0.2 %

  @override
  void initState() {
    super.initState();
    _fetchRate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchRate() async {
    final rate = await ExchangeRateService.getExchangeRate(
      baseCurrency: 'USD',
      targetCurrency: 'INR',
    );
    if (mounted) {
      setState(() {
        if (rate != null) {
          _exchangeRate = rate;
          _isLiveRate = true;
        }
        _rateLoading = false;
      });
    }
  }

  double get _sendAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  /// After our 0.2 % service fee
  double get _feeUsd => _sendAmount * _remitflowFeeFrac;

  /// What the receiver actually gets in USD (after our fee)
  double get _receivedUsd => _sendAmount - _feeUsd;

  /// Converted to INR at mid-market
  double get _receivedInr => _receivedUsd * _exchangeRate;

  bool get _canSubmit =>
      _sendAmount > 0 &&
      !AppDataService().isTransferSubmitting;

  Future<void> _submitTransfer() async {
    final appData = AppDataService();
    try {
      final receipt = await appData.submitTransfer(
        recipientId: widget.recipient.id,
        amountUsd: _sendAmount,
      );
      if (!mounted) return;

      // Pop back to home (pop both this and the recipient screen)
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent \$${_sendAmount.toStringAsFixed(2)} to ${widget.recipient.preferredName}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.vaultGreen,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appData.transferErrorMessage ?? 'Transfer failed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataService();
    final recipient = widget.recipient;
    final initial = recipient.preferredName.isNotEmpty
        ? recipient.preferredName[0].toUpperCase()
        : 'R';

    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppTheme.surfaceContainerLowest,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.onSurface,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Send Money',
              style: GoogleFonts.newsreader(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        // ── Recipient badge ──────────────────────────
                        const SizedBox(height: 16),
                        _RecipientBadge(
                          recipient: recipient,
                          initial: initial,
                        ),

                        const SizedBox(height: 40),

                        // ── Amount input ─────────────────────────────
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$',
                              style: GoogleFonts.newsreader(
                                fontSize: 40,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IntrinsicWidth(
                              child: TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: GoogleFonts.newsreader(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.vaultGreen,
                                  letterSpacing: -1.5,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                cursorColor: AppTheme.vaultGreen,
                                autofocus: true,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── Conversion breakdown card ────────────────
                        if (_sendAmount > 0)
                          _ConversionCard(
                            sendAmountUsd: _sendAmount,
                            feeUsd: _feeUsd,
                            receivedUsd: _receivedUsd,
                            receivedInr: _receivedInr,
                            exchangeRate: _exchangeRate,
                            isLiveRate: _isLiveRate,
                            rateLoading: _rateLoading,
                            recipientName: recipient.preferredName,
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Send button ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submitTransfer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        disabledBackgroundColor:
                            AppTheme.surfaceContainerHigh,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: _canSubmit ? 8 : 0,
                        shadowColor:
                            AppTheme.primaryContainer.withValues(alpha: 0.4),
                      ),
                      child: appData.isTransferSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1C1C),
                              ),
                            )
                          : Text(
                              'SEND MONEY',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _canSubmit
                                    ? const Color(0xFF1A1C1C)
                                    : AppTheme.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RECIPIENT BADGE — Small centered card showing who you're sending to
// ═══════════════════════════════════════════════════════════════════════

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({
    required this.recipient,
    required this.initial,
  });

  final RecipientSummary recipient;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 32,
          backgroundColor: AppTheme.surfaceContainer,
          backgroundImage: recipient.photoUrl != null
              ? NetworkImage(recipient.photoUrl!)
              : null,
          child: recipient.photoUrl == null
              ? Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.vaultGreen,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          recipient.preferredName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          recipient.email,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CONVERSION CARD — fee breakdown + INR the receiver gets
// ═══════════════════════════════════════════════════════════════════════

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({
    required this.sendAmountUsd,
    required this.feeUsd,
    required this.receivedUsd,
    required this.receivedInr,
    required this.exchangeRate,
    required this.isLiveRate,
    required this.rateLoading,
    required this.recipientName,
  });

  final double sendAmountUsd;
  final double feeUsd;
  final double receivedUsd;
  final double receivedInr;
  final double exchangeRate;
  final bool isLiveRate;
  final bool rateLoading;
  final String recipientName;

  @override
  Widget build(BuildContext context) {
    final inrFmt = NumberFormat('#,##,##0.00');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'TRANSFER BREAKDOWN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              // Live / Cached indicator
              if (!rateLoading)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isLiveRate
                            ? AppTheme.vaultGreen
                            : AppTheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLiveRate ? 'LIVE' : 'CACHED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isLiveRate
                            ? AppTheme.vaultGreen
                            : AppTheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 1: You send
          _breakdownRow(
            label: 'You send',
            value: '\$${sendAmountUsd.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 10),

          // Row 2: Our fee
          _breakdownRow(
            label: 'RemitFlow fee (0.2%)',
            value: '-\$${feeUsd.toStringAsFixed(2)}',
            valueColor: AppTheme.onSurfaceVariant,
          ),

          const SizedBox(height: 10),

          // Row 3: Exchange rate
          _breakdownRow(
            label: 'Exchange rate',
            value: rateLoading
                ? '...'
                : '1 USD = ₹${exchangeRate.toStringAsFixed(2)}',
            valueColor: AppTheme.onSurfaceVariant,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: AppTheme.surfaceContainer.withValues(alpha: 0.6),
              height: 1,
            ),
          ),

          // Row 4: Receiver gets (INR) — the hero number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${recipientName.split(' ').first} receives',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
              rateLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.vaultGreen,
                      ),
                    )
                  : Text(
                      '₹${inrFmt.format(receivedInr)}',
                      style: GoogleFonts.newsreader(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.vaultGreen,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}
