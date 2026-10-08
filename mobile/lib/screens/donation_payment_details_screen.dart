import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/payment_details.dart';
import '../services/auth_service.dart';
import '../services/payment_details_service.dart';
import '../widgets/app_background.dart';

class DonationPaymentDetailsScreen extends StatefulWidget {
  final AuthUser user;

  const DonationPaymentDetailsScreen({super.key, required this.user});

  @override
  State<DonationPaymentDetailsScreen> createState() =>
      _DonationPaymentDetailsScreenState();
}

class _DonationPaymentDetailsScreenState
    extends State<DonationPaymentDetailsScreen> {
  final PaymentDetailsService _service = PaymentDetailsService.instance;

  PaymentDetails _details = const PaymentDetails();
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers for editing
  late final TextEditingController _upiIdController;
  late final TextEditingController _payeeNameController;
  late final TextEditingController _holderNameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accNumberController;
  late final TextEditingController _ifscController;
  late final TextEditingController _branchController;
  late final TextEditingController _accTypeController;

  // Controller for donation amount
  final TextEditingController _amountController = TextEditingController(
    text: '100',
  );

  String? _qrBarcodeBase64;

  bool get _isAdmin => widget.user.isAdmin;

  @override
  void initState() {
    super.initState();
    _upiIdController = TextEditingController();
    _payeeNameController = TextEditingController();
    _holderNameController = TextEditingController();
    _bankNameController = TextEditingController();
    _accNumberController = TextEditingController();
    _ifscController = TextEditingController();
    _branchController = TextEditingController();
    _accTypeController = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accNumberController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _accTypeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final details = await _service.loadDetails();
    if (!mounted) return;

    setState(() {
      _details = details;
      _qrBarcodeBase64 = details.qrBarcodeBase64;
      _upiIdController.text = details.upiId;
      _payeeNameController.text = details.payeeName;
      _holderNameController.text = details.accountHolderName;
      _bankNameController.text = details.bankName;
      _accNumberController.text = details.accountNumber;
      _ifscController.text = details.ifscCode;
      _branchController.text = details.branch;
      _accTypeController.text = details.accountType;
      _isLoading = false;
    });
  }

  Future<void> _pickBarcodeImage() async {
    if (!_isAdmin) return;

    try {
      final PlatformFile? selected = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (selected != null) {
        final bytes = await selected.readAsBytes();

        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('फोटोचा आकार ५ MB पेक्षा कमी असावा'),
              ),
            );
          }
          return;
        }

        final base64String = base64Encode(bytes);
        setState(() {
          _qrBarcodeBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('फोटो निवडताना अडचण आली: $e')),
        );
      }
    }
  }

  void _removeBarcodeImage() {
    setState(() {
      _qrBarcodeBase64 = null;
    });
  }

  Future<void> _saveDetails() async {
    if (!_isAdmin) return;

    setState(() => _isSaving = true);

    final updated = PaymentDetails(
      upiId: _upiIdController.text.trim(),
      payeeName: _payeeNameController.text.trim().isEmpty
          ? 'दुर्गसेवक'
          : _payeeNameController.text.trim(),
      qrBarcodeBase64: _qrBarcodeBase64,
      accountHolderName: _holderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _accNumberController.text.trim(),
      ifscCode: _ifscController.text.trim().toUpperCase(),
      branch: _branchController.text.trim(),
      accountType: _accTypeController.text.trim().isEmpty
          ? 'बचत खाते (Savings)'
          : _accTypeController.text.trim(),
    );

    await _service.saveDetails(updated);

    if (!mounted) return;

    setState(() {
      _details = updated;
      _isEditing = false;
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI व बँक तपशील यशस्वीरित्या जतन केले'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _launchPayment() async {
    final upiId = _details.upiId.trim();
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया आधी ॲडमिनने UPI आयडी सेट करावा.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया योग्य देणगी रक्कम प्रविष्ट करा'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final success = await _service.launchUpiPayment(
      upiId: upiId,
      payeeName: _details.payeeName,
      amount: amount,
      note: 'दुर्गसेवक देणगी',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'UPI ॲप उघडता आले नाही. कृपया UPI आयडी ($upiId) कॉपी करून स्वतःच्या ॲपमधून पेमेंट करा किंवा QR कोड स्कॅन करा.',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'कॉपी करा',
            textColor: Colors.yellow,
            onPressed: () => _copyToClipboard(upiId, 'UPI आयडी'),
          ),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label कॉपी केला: ${text.trim()}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFullScreenImage(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'स्कॅन करण्यासाठी हा QR कोड वापरा',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('देणगी UPI व बँक तपशील'),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: _isEditing ? 'रद्द करा' : 'माहिती संपादित करा',
              icon: Icon(_isEditing ? Icons.close : Icons.edit_note),
              onPressed: () {
                if (_isEditing) {
                  // Cancel edits and reload
                  _loadData();
                  setState(() => _isEditing = false);
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
        ],
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isAdmin && !_isEditing)
                      _buildAdminNoticeBadge(),
                    if (_isEditing)
                      _buildEditingForm()
                    else
                      _buildViewMode(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAdminNoticeBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.deepOrange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'तुम्ही ॲडमिन आहात. वरील एडिट आयकॉनवर क्लिक करून QR बारकोड व बँक तपशील बदलू शकता.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isEditing = true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(50, 30),
            ),
            child: const Text('बदला', style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  // ================= VIEW MODE =================
  Widget _buildViewMode() {
    Uint8List? barcodeBytes;
    if (_details.qrBarcodeBase64 != null &&
        _details.qrBarcodeBase64!.trim().isNotEmpty) {
      try {
        barcodeBytes = base64Decode(_details.qrBarcodeBase64!.trim());
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. UPI QR Code & ID Card
        _buildUpiCard(barcodeBytes),

        const SizedBox(height: 16),

        // 2. Pay Now Section
        _buildPayNowSection(),

        const SizedBox(height: 16),

        // 3. Bank Details Card
        _buildBankDetailsCard(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUpiCard(Uint8List? barcodeBytes) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2, color: Colors.deepOrange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UPI स्कॅन व पे (QR Barcode)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _details.payeeName.isEmpty ? 'दुर्गसेवक' : _details.payeeName,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Barcode Display
            if (barcodeBytes != null) ...[
              GestureDetector(
                onTap: () => _showFullScreenImage(barcodeBytes),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      barcodeBytes,
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.zoom_in, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'मोठा करून पाहण्यासाठी फोटोवर स्पर्श करा',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade500),
                    const SizedBox(height: 12),
                    Text(
                      _isAdmin
                          ? 'कोणताही UPI बारकोड अपलोड केलेला नाही.\nखालील एडिट बटण दाबून बारकोड फोटो जोडा.'
                          : 'मंडळाचा UPI बारकोड लवकरच उपलब्ध होईल.\nतुम्ही खालील UPI ID वापरून पैसे भरू शकता.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // UPI ID Display Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.greenAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UPI ID',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          _details.upiId.isEmpty
                              ? 'उपलब्ध नाही'
                              : _details.upiId,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _details.upiId.isEmpty
                                ? Colors.grey
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_details.upiId.isNotEmpty)
                    IconButton(
                      tooltip: 'UPI ID कॉपी करा',
                      icon: const Icon(Icons.copy, color: Colors.orangeAccent, size: 20),
                      onPressed: () =>
                          _copyToClipboard(_details.upiId, 'UPI ID'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayNowSection() {
    final quickAmounts = [100, 200, 500, 1000, 2100];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.touch_app, color: Colors.deepOrange, size: 22),
                SizedBox(width: 8),
                Text(
                  'थेट ॲपमधून देणगी भरा (Pay Now)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'रक्कम निवडा आणि खालील बटण दाबा. फोनमधील PhonePe, Google Pay, Paytm इत्यादी उघडेल.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Quick Amount Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: quickAmounts.map((amt) {
                  final isSelected = _amountController.text == amt.toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('₹$amt'),
                      selected: isSelected,
                      selectedColor: Colors.deepOrange,
                      onSelected: (_) {
                        setState(() {
                          _amountController.text = amt.toString();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'देणगी रक्कम (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
                hintText: 'उदा. 500',
              ),
            ),

            const SizedBox(height: 18),

            // Pay Now Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _launchPayment,
                icon: const Icon(Icons.flash_on, size: 24),
                label: const Text(
                  'Pay Now (आता पैसे भरा)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'बँक खात्याचे तपशील (Bank Details)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'NEFT / IMPS / RTGS द्वारे देणगीसाठी',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            _buildBankRow(
              label: 'बँकेचे नाव (Bank Name)',
              value: _details.bankName,
              icon: Icons.business,
            ),
            const SizedBox(height: 12),

            _buildBankRow(
              label: 'खातेदाराचे नाव (Account Holder)',
              value: _details.accountHolderName,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),

            _buildBankRow(
              label: 'खाते क्रमांक (Account Number)',
              value: _details.accountNumber,
              icon: Icons.tag,
              canCopy: true,
            ),
            const SizedBox(height: 12),

            _buildBankRow(
              label: 'IFSC कोड',
              value: _details.ifscCode,
              icon: Icons.code,
              canCopy: true,
            ),
            const SizedBox(height: 12),

            _buildBankRow(
              label: 'शाखा (Branch)',
              value: _details.branch,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),

            _buildBankRow(
              label: 'खाते प्रकार (Account Type)',
              value: _details.accountType,
              icon: Icons.credit_card,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankRow({
    required String label,
    required String value,
    required IconData icon,
    bool canCopy = false,
  }) {
    final displayValue = value.trim().isEmpty ? 'माहिती उपलब्ध नाही' : value.trim();
    final isEmpty = value.trim().isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                  color: isEmpty ? Colors.grey : Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (canCopy && !isEmpty)
          IconButton(
            tooltip: '$label कॉपी करा',
            icon: const Icon(Icons.copy, size: 18, color: Colors.orangeAccent),
            onPressed: () => _copyToClipboard(displayValue, label),
          ),
      ],
    );
  }

  // ================= ADMIN EDITING FORM =================
  Widget _buildEditingForm() {
    Uint8List? currentBarcodeBytes;
    if (_qrBarcodeBase64 != null && _qrBarcodeBase64!.trim().isNotEmpty) {
      try {
        currentBarcodeBytes = base64Decode(_qrBarcodeBase64!.trim());
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Admin Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withAlpha(90)),
          ),
          child: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ॲडमिन संपादन: UPI बारकोड व बँक माहिती बदला. सेव्ह केल्यानंतर ही माहिती सर्व सदस्यांना दिसेल.',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // QR Barcode Upload Section
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '१. UPI बारकोड (QR Code Image)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'मंडळाचा किंवा ॲडमिनचा अधिकृत UPI QR कोड फोटो गॅलरी किंवा फाईल्समधून अपलोड करा.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                if (currentBarcodeBytes != null) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          currentBarcodeBytes,
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickBarcodeImage,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('फोटो बदला'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _removeBarcodeImage,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('काढून टाका'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickBarcodeImage,
                      icon: const Icon(Icons.add_photo_alternate, size: 22),
                      label: const Text('बारकोड / QR फोटो निवडा'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        side: const BorderSide(color: Colors.deepOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // UPI Fields
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '२. UPI तपशील',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _upiIdController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID *',
                    hintText: 'उदा. durgasevak@upi किंवा 9876543210@ybl',
                    prefixIcon: Icon(Icons.payment),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _payeeNameController,
                  decoration: const InputDecoration(
                    labelText: 'स्वीकारकर्त्याचे नाव / Payee Name',
                    hintText: 'उदा. दुर्गसेवक',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Bank Fields
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '३. बँक तपशील (Bank Details)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'बँकेचे नाव (Bank Name)',
                    hintText: 'उदा. बँक ऑफ महाराष्ट्र / State Bank of India',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _holderNameController,
                  decoration: const InputDecoration(
                    labelText: 'खातेदाराचे नाव (Account Holder Name)',
                    hintText: 'उदा. दुर्गसेवक प्रतिष्ठाण',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _accNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'खाते क्रमांक (Account Number)',
                    hintText: 'उदा. 60123456789',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC कोड',
                    hintText: 'उदा. MAHB0001234',
                    prefixIcon: Icon(Icons.code),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _branchController,
                  decoration: const InputDecoration(
                    labelText: 'शाखा (Branch)',
                    hintText: 'उदा. कोल्हापूर मुख्य शाखा',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _accTypeController,
                  decoration: const InputDecoration(
                    labelText: 'खाते प्रकार (Account Type)',
                    hintText: 'उदा. बचत खाते (Savings) / चालू खाते (Current)',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Save & Cancel Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        _loadData();
                        setState(() => _isEditing = false);
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('रद्द करा'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDetails,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'जतन करत आहे...' : 'माहिती सेव्ह करा',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
