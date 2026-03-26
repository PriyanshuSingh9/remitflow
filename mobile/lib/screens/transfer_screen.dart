import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _amountController = TextEditingController(text: "0");
  int _selectedRecipientIndex = -1;

  final List<Map<String, String>> _recipients = [
    {
      'name': 'Priya Sharma',
      'avatar': 'https://i.pravatar.cc/150?u=priya',
    },
    {
      'name': 'Rahul Verma',
      'avatar': 'https://i.pravatar.cc/150?u=rahul',
    },
    {
      'name': 'John Davis',
      'avatar': 'https://i.pravatar.cc/150?u=john',
    },
    {
      'name': 'Sarah Smith',
      'avatar': 'https://i.pravatar.cc/150?u=sarah',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.onSurface, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    // Amount Input
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current Balance: \$2,450.00',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 56),

                    // Recipient Section
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

                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: AppTheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.onSurfaceVariant, size: 20),
                          hintText: 'Name, email, or phone',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppTheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Horizontal List of Recipients
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recipients.length + 1, // +1 for "Add New"
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildAddNewRecipient();
                          }
                          final recipientIndex = index - 1;
                          final recipient = _recipients[recipientIndex];
                          final isSelected = _selectedRecipientIndex == recipientIndex;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRecipientIndex = recipientIndex;
                                // Move cursor to end of text when a recipient is selected to simulate natural flow
                                _amountController.selection = TextSelection.fromPosition(TextPosition(offset: _amountController.text.length));
                              });
                            },
                            child: _buildRecipientItem(
                              name: recipient['name']!,
                              avatar: recipient['avatar']!,
                              isSelected: isSelected,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Send Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedRecipientIndex != -1 ? () {
                    // Action to send money
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transferred \$${_amountController.text} to ${_recipients[_selectedRecipientIndex]['name']}!'),
                        backgroundColor: AppTheme.vaultGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    elevation: _selectedRecipientIndex != -1 ? 8 : 0,
                    shadowColor: AppTheme.primaryContainer.withOpacity(0.4),
                  ),
                  child: Text(
                    'SEND MONEY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _selectedRecipientIndex != -1 
                          ? const Color(0xFF1A1C1C) 
                          : AppTheme.onSurfaceVariant.withOpacity(0.5),
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewRecipient() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceContainerLow,
              border: Border.all(
                color: AppTheme.outlineVariant.withOpacity(0.5),
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(Icons.add_rounded, color: AppTheme.onSurfaceVariant, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'New',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientItem({required String name, required String avatar, required bool isSelected}) {
    final firstName = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSelected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: AppTheme.vaultGreen, width: 2) : null,
            ),
            child: CircleAvatar(
              radius: isSelected ? 27 : 30,
              backgroundImage: NetworkImage(avatar),
              backgroundColor: AppTheme.surfaceContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            firstName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
