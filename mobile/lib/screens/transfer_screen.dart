import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedRecipientId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppDataService().searchRecipients('');
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      AppDataService().searchRecipients(_searchController.text);
    });
  }

  RecipientSummary? _findRecipient(List<RecipientSummary> recipients) {
    for (final recipient in recipients) {
      if (recipient.id == _selectedRecipientId) {
        return recipient;
      }
    }
    return null;
  }

  Future<void> _submitTransfer() async {
    final appData = AppDataService();
    final recipients = appData.recipients;
    final amount = double.tryParse(_amountController.text.trim());
    final recipient = _findRecipient(recipients);

    if (recipient == null || amount == null || amount <= 0) {
      return;
    }

    try {
      final receipt = await appData.submitTransfer(
        recipientId: recipient.id,
        amountUsd: amount,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer created for ${recipient.preferredName}. ${_formatUsd(receipt.senderBalanceAfter)} remaining.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.vaultGreen,
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appData.transferErrorMessage ?? 'Transfer failed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataService();
    final dashboard = appData.dashboard;
    final currentBalance = dashboard?.user.availableBalanceUsd ?? 0;

    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) {
        final recipients = appData.recipients;
        final selectedRecipient = _findRecipient(recipients);
        final amount = double.tryParse(_amountController.text.trim()) ?? 0;
        final canSubmit =
            selectedRecipient != null &&
            amount > 0 &&
            amount <= currentBalance &&
            !appData.isTransferSubmitting;

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
              'Transfer',
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
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
                                  fontSize: 64,
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
                        const SizedBox(height: 12),
                        Text(
                          'Current Balance: ${_formatUsd(currentBalance)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        if (amount > currentBalance) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Amount exceeds your available balance.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 56),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select Recipient',
                            style: GoogleFonts.newsreader(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: AppTheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              icon: const Icon(
                                Icons.search_rounded,
                                color: AppTheme.onSurfaceVariant,
                                size: 20,
                              ),
                              hintText: 'Name, email, or phone',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.onSurfaceVariant.withOpacity(
                                  0.7,
                                ),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (appData.isRecipientsLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                              color: AppTheme.vaultGreen,
                            ),
                          )
                        else if (appData.recipientsErrorMessage != null)
                          _RecipientsError(
                            message: appData.recipientsErrorMessage!,
                            onRetry: () => appData.searchRecipients(
                              _searchController.text,
                            ),
                          )
                        else if (recipients.isEmpty)
                          _EmptyRecipients(query: _searchController.text)
                        else
                          SizedBox(
                            height: 124,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: recipients.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final recipient = recipients[index];
                                final isSelected =
                                    recipient.id == _selectedRecipientId;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedRecipientId = recipient.id;
                                      _amountController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset:
                                                  _amountController.text.length,
                                            ),
                                          );
                                    });
                                  },
                                  child: _RecipientCard(
                                    recipient: recipient,
                                    isSelected: isSelected,
                                  ),
                                );
                              },
                            ),
                          ),
                        if (selectedRecipient != null) ...[
                          const SizedBox(height: 28),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfer Preview',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.secondary,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${_formatUsd(amount)} to ${selectedRecipient.preferredName}',
                                  style: GoogleFonts.newsreader(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_flagForCountry(selectedRecipient.country)}  ${selectedRecipient.email}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                if (dashboard != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Estimated payout: ₹${NumberFormat('#,##,##0.00').format(amount * dashboard.exchangeRate.rate)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.vaultGreen,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submitTransfer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: canSubmit ? 8 : 0,
                        shadowColor: AppTheme.primaryContainer.withOpacity(0.4),
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
                                color: canSubmit
                                    ? const Color(0xFF1A1C1C)
                                    : AppTheme.onSurfaceVariant.withOpacity(
                                        0.5,
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

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.recipient, required this.isSelected});

  final RecipientSummary recipient;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final initial = recipient.preferredName.isNotEmpty
        ? recipient.preferredName[0].toUpperCase()
        : 'R';

    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSelected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: AppTheme.vaultGreen, width: 2)
                  : null,
            ),
            child: CircleAvatar(
              radius: isSelected ? 27 : 30,
              backgroundColor: AppTheme.surfaceContainer,
              backgroundImage: recipient.photoUrl != null
                  ? NetworkImage(recipient.photoUrl!)
                  : null,
              child: recipient.photoUrl == null
                  ? Text(
                      initial,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.vaultGreen,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipient.preferredName.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.onSurface
                  : AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _flagForCountry(recipient.country),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _RecipientsError extends StatelessWidget {
  const _RecipientsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.error,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry search')),
        ],
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        query.trim().isEmpty
            ? 'No recipients are available yet.'
            : 'No recipients matched "$query".',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
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
