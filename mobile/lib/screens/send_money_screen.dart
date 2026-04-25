import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import 'receipt_screen.dart';

/// Step 2 of the transfer flow — enter USD amount, see full fee breakdown
/// (Transak on-ramp + Polygon gas + OnMeta off-ramp + RemitFlow platform fee),
/// and send. No wallet balance shown.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key, required this.recipient});

  final RecipientSummary recipient;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();

  double _exchangeRate = 83.42;
  bool _rateLoading = true;
  bool _isLiveRate = false;

  // ── Real fee structure (matches backend feeUsd = amountUsd * 0.025) ─────
  //
  // | Component         | Rate  | Provider  | Notes                      |
  // |-------------------|-------|-----------|----------------------------|
  // | On-ramp           | 1.50% | Transak   | USD → USDC card purchase   |
  // | Polygon gas       | fixed | Polygon   | Near-zero on PoS           |
  // | Off-ramp          | 1.50% | OnMeta    | USDC → INR bank credit     |
  // | Platform          | 1.00% | RemitFlow | Our margin                 |
  // | Total percentage  | 4.00% |           |                            |
  //
  static const double _transakRate = 0.015; // 1.50 %
  static const double _gasFlat = 0.00; // included in the 4% headline fee
  static const double _onmetaRate = 0.015; // 1.50 %
  static const double _remitflowRate = 0.010; // 1.00 %
  // Sum of percentage fees = 4% (matches backend factor 0.04)

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

  double get _sendAmount => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _transakFee => _sendAmount * _transakRate;
  double get _onmetaFee => _sendAmount * _onmetaRate;
  double get _remitflowFee => _sendAmount * _remitflowRate;
  double get _totalFeeUsd =>
      _transakFee + _onmetaFee + _remitflowFee + _gasFlat;

  /// What the receiver gets in USD (after all % fees; gas is protocol-level)
  double get _receivedUsd =>
      _sendAmount * (1 - _transakRate - _onmetaRate - _remitflowRate);
  double get _receivedInr => _receivedUsd * _exchangeRate;

  bool get _canSubmit =>
      _sendAmount > 0 && !AppDataService().isTransferSubmitting;

  Future<void> _submitTransfer() async {
    final appData = AppDataService();
    try {
      final receipt = await appData.submitTransfer(
        recipientId: widget.recipient.id,
        amountUsd: _sendAmount,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appData.transferErrorMessage ?? 'Transfer failed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    final initial = recipient.preferredName.isNotEmpty
        ? recipient.preferredName[0].toUpperCase()
        : 'R';

    return ListenableBuilder(
      listenable: AppDataService(),
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
                        const SizedBox(height: 16),
                        _RecipientBadge(recipient: recipient, initial: initial),
                        const SizedBox(height: 40),

                        // ── Amount input ────────────────────────────
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

                        if (_sendAmount > 0)
                          _ConversionCard(
                            sendAmountUsd: _sendAmount,
                            transakFee: _transakFee,
                            onmetaFee: _onmetaFee,
                            remitflowFee: _remitflowFee,
                            gasFlat: _gasFlat,
                            totalFeeUsd: _totalFeeUsd,
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
                        disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: _canSubmit ? 8 : 0,
                        shadowColor: AppTheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      child: AppDataService().isTransferSubmitting
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
// RECIPIENT BADGE
// ═══════════════════════════════════════════════════════════════════════

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({required this.recipient, required this.initial});

  final RecipientSummary recipient;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
// CONVERSION CARD — full 4-component fee breakdown
// ═══════════════════════════════════════════════════════════════════════

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({
    required this.sendAmountUsd,
    required this.transakFee,
    required this.onmetaFee,
    required this.remitflowFee,
    required this.gasFlat,
    required this.totalFeeUsd,
    required this.receivedInr,
    required this.exchangeRate,
    required this.isLiveRate,
    required this.rateLoading,
    required this.recipientName,
  });

  final double sendAmountUsd;
  final double transakFee;
  final double onmetaFee;
  final double remitflowFee;
  final double gasFlat;
  final double totalFeeUsd;
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
          // Header row
          Row(
            children: [
              Text(
                'FEE BREAKDOWN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              if (!rateLoading) _RateChip(isLive: isLiveRate),
            ],
          ),

          const SizedBox(height: 16),

          // You send
          _Row(
            label: 'You send',
            value: '\$${sendAmountUsd.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 12),

          // Collapsible fee breakdown
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total fees (4%)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      '-\$${totalFeeUsd.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                trailing: const SizedBox.shrink(),
                iconColor: AppTheme.onSurfaceVariant,
                collapsedIconColor: AppTheme.onSurfaceVariant,
                children: [
                  Divider(
                    height: 1,
                    color: AppTheme.surfaceContainer.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    label: 'On-ramp fee (Transak, 1.5%)',
                    value: '-\$${transakFee.toStringAsFixed(2)}',
                    valueColor: AppTheme.onSurfaceVariant,
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'Polygon network gas',
                    value: '~\$${gasFlat.toStringAsFixed(2)}',
                    valueColor: AppTheme.onSurfaceVariant,
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'Off-ramp fee (OnMeta, 1.5%)',
                    value: '-\$${onmetaFee.toStringAsFixed(2)}',
                    valueColor: AppTheme.onSurfaceVariant,
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    label: 'RemitFlow platform (1%)',
                    value: '-\$${remitflowFee.toStringAsFixed(2)}',
                    valueColor: AppTheme.onSurfaceVariant,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Exchange rate
          _Row(
            label: 'Exchange rate',
            value: rateLoading
                ? '...'
                : '1 USD = ₹${exchangeRate.toStringAsFixed(2)}',
            valueColor: AppTheme.onSurfaceVariant,
            isSmall: true,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: AppTheme.surfaceContainer.withValues(alpha: 0.6),
            ),
          ),

          // Receiver gets — hero number
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

          const SizedBox(height: 10),
          Text(
            'Estimated delivery: 5–10 minutes via UPI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isLive ? AppTheme.vaultGreen : AppTheme.onSurfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isLive ? 'LIVE' : 'CACHED',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isLive ? AppTheme.vaultGreen : AppTheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.isSmall = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final sz = isSmall ? 12.0 : 13.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: sz,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: sz,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}
