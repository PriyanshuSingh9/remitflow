import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_models.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import 'send_money_screen.dart';

/// Step 1 of the transfer flow — pick a recipient from registered users.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

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
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      AppDataService().searchRecipients(_searchController.text);
    });
  }

  void _onRecipientSelected(RecipientSummary recipient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SendMoneyScreen(recipient: recipient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = AppDataService();

    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) {
        final recipients = appData.recipients;

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
              'Send To',
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
                // ── Search bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Container(
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
                        hintText: 'Search by name or email',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  AppDataService().searchRecipients('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Recipient list ───────────────────────────────
                Expanded(
                  child: _buildRecipientList(
                    appData: appData,
                    recipients: recipients,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientList({
    required AppDataService appData,
    required List<RecipientSummary> recipients,
  }) {
    if (appData.isRecipientsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.vaultGreen),
      );
    }

    if (appData.recipientsErrorMessage != null) {
      return _RecipientsError(
        message: appData.recipientsErrorMessage!,
        onRetry: () => appData.searchRecipients(_searchController.text),
      );
    }

    if (recipients.isEmpty) {
      return _EmptyRecipients(query: _searchController.text);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: recipients.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppTheme.surfaceContainer.withValues(alpha: 0.7),
      ),
      itemBuilder: (context, index) {
        final recipient = recipients[index];
        return _RecipientTile(
          recipient: recipient,
          onTap: () => _onRecipientSelected(recipient),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RECIPIENT TILE — Full-width row for vertical list (GPay style)
// ═══════════════════════════════════════════════════════════════════════

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({required this.recipient, required this.onTap});

  final RecipientSummary recipient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = recipient.preferredName.isNotEmpty
        ? recipient.preferredName[0].toUpperCase()
        : 'R';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.surfaceContainer,
              backgroundImage: recipient.photoUrl != null
                  ? NetworkImage(recipient.photoUrl!)
                  : null,
              child: recipient.photoUrl == null
                  ? Text(
                      initial,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.vaultGreen,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient.preferredName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recipient.email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Country flag + chevron
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _flagForCountry(recipient.country),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ERROR / EMPTY STATES
// ═══════════════════════════════════════════════════════════════════════

class _RecipientsError extends StatelessWidget {
  const _RecipientsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'RETRY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              query.trim().isEmpty
                  ? 'No registered recipients yet.'
                  : 'No recipients matched "$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════

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
