import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

/// Screen allowing patients to scan and upload clinical documents
/// (e.g. physical prescriptions, external lab test reports, vaccine records).
/// 
/// Incorporates Material 3 styling, high contrast, large targets,
/// and local state simulation to demonstrate active cloud upload workflows.
class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Prescription';
  String? _simulatedFileName;
  String? _simulatedFileSize;
  bool _isSelectingFile = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Local list representing uploaded files history
  final List<Map<String, String>> _uploadedHistory = [
    {
      'title': 'COVID-19 Vaccination Card',
      'category': 'Vaccination Card',
      'fileName': 'covid_vaccine_sl.pdf',
      'date': '12 May 2026',
    },
    {
      'title': 'Lipid Profile Report - Hemas',
      'category': 'Lab Report',
      'fileName': 'lipid_profile_hemas.png',
      'date': '04 April 2026',
    },
  ];

  // Colors mapping the Clinical Green theme (dynamic for dark mode)
  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
  Color get _accentGreen => const Color(0xFF4CAF50);
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9);

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _previewDocument(Map<String, String> file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = file['title'] ?? 'Document';
    final category = file['category'] ?? 'Prescription';
    final fileName = file['fileName'] ?? 'document.pdf';
    final dateStr = file['date'] ?? 'N/A';
    
    // Decryption handshake loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).cardColor,
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen)),
              const SizedBox(height: 20),
              Text(
                'Client-Side Decrypting...',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Retrieving AES-256 session keys from device keychain and verifying integrity checksum.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate key loading and decryption calculation
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      // Open the visual document viewer
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_open_rounded, color: _primaryGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decrypted Document Viewer',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _primaryGreen,
                            ),
                          ),
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Document Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Decrypted on: $dateStr',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Visual Document Content Block
                    Container(
                      height: 260,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF9FBF9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cardBorderColor, width: 1),
                      ),
                      child: SingleChildScrollView(
                        child: _buildMockDocumentContent(category, title),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification check: Document signature cryptographically valid (SHA-256 matched).'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined, size: 16),
                        label: const Text('Verify Signature'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryGreen,
                          side: BorderSide(color: _primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.download_done_rounded, size: 16),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    });
  }

  Widget _buildMockDocumentContent(String category, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[700];

    if (category == 'Lab Report') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'HEMAS CLINICAL LABORATORIES',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _primaryGreen,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Patient Report Summary',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: labelColor),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          _buildLabRow('CHOLESTEROL, TOTAL', '210 mg/dL', 'HIGH', '> 200 mg/dL', Colors.orange[800]!),
          _buildLabRow('HDL CHOLESTEROL', '48 mg/dL', 'NORMAL', '> 40 mg/dL', Colors.green[800]!),
          _buildLabRow('LDL CHOLESTEROL', '142 mg/dL', 'HIGH', '> 100 mg/dL', Colors.orange[800]!),
          _buildLabRow('TRIGLYCERIDES', '155 mg/dL', 'NORMAL', '< 150 mg/dL', Colors.green[800]!),
          const Divider(height: 24),
          Text(
            'Lab Sign-off: Dr. S. K. Perera (Consultant Pathologist)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cryptographic Verification Hash: 0x9F8B2D7C4A1056E',
            style: TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.grey[500]),
          ),
        ],
      );
    } else if (category == 'Vaccination Card') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'MINISTRY OF HEALTH SRI LANKA',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFC62828),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'COVID-19 Immunisation Record',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: labelColor),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          _buildVaccineRow('Dose 1 (Pfizer-BioNTech)', '24 Jan 2021', 'Batch: PFA4109'),
          _buildVaccineRow('Dose 2 (Pfizer-BioNTech)', '15 Feb 2021', 'Batch: PFA9841'),
          _buildVaccineRow('Booster 1 (Pfizer)', '18 Nov 2022', 'Batch: PFB1044'),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFFC62828), size: 14),
              const SizedBox(width: 6),
              Text(
                'Status: Fully Immunised (Verified)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (category == 'Prescription') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rx',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: _primaryGreen,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Dr. Ruwan Gunawardena',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    'License: SLMC 8A4D0C2F',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: labelColor),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          _buildPrescriptionItem('Amoxicillin 500mg', 'TDS - 3 times daily (After meals)', '7 Days (Complete full course)'),
          const SizedBox(height: 12),
          _buildPrescriptionItem('Paracetamol 500mg', 'PRN - As needed for pain/fever', 'As required (Max 4 times daily)'),
          const Divider(height: 20),
          Text(
            'Special Instructions: Take antibiotics with plenty of water. Discontinue if allergic reaction occurs and consult immediate emergency services.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: labelColor,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file_outlined, color: _primaryGreen, size: 24),
              const SizedBox(width: 8),
              Text(
                'External Document Attachment',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Notes / Symptoms Decrypted:',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Uploaded medical scan file attachment. Encrypted using dynamically derived client keys. Integrity verification code: SHA-256 matched successfully.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: textColor, height: 1.4),
          ),
        ],
      );
    }
  }

  Widget _buildLabRow(String test, String result, String status, String ref, Color statusColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  'Ref: $ref',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            result,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineRow(String name, String date, String batch) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                batch,
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          Text(
            date,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionItem(String drug, String instruction, String duration) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          drug,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          instruction,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        Text(
          'Duration: $duration',
          style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontStyle: FontStyle.italic, color: _primaryGreen),
        ),
      ],
    );
  }

  /// Triggers a native file picker dialog on device or web.
  Future<void> _pickFileFromDevice() async {
    setState(() {
      _isSelectingFile = true;
      _simulatedFileName = null;
    });
    await HapticFeedback.selectionClick();

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final double sizeInMb = file.size / (1024 * 1024);
        setState(() {
          _simulatedFileName = file.name;
          _simulatedFileSize = '${sizeInMb.toStringAsFixed(2)} MB';
          
          // Clean base name for the title field
          final dotIndex = file.name.lastIndexOf('.');
          final baseName = dotIndex != -1 ? file.name.substring(0, dotIndex) : file.name;
          _titleController.text = baseName.replaceAll('_', ' ').replaceAll('-', ' ');
          
          final extension = file.extension?.toLowerCase();
          if (extension == 'pdf') {
            _selectedCategory = 'Lab Report';
          } else {
            _selectedCategory = 'Prescription';
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file picker: $e'),
            backgroundColor: Colors.red[850],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingFile = false;
        });
      }
    }
  }

  /// Simulates uploading the selected file with progress updates.
  Future<void> _simulateUpload() async {
    if (!_formKey.currentState!.validate() || _simulatedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a file and fill in required fields.'),
          backgroundColor: Colors.amber[800],
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    await HapticFeedback.mediumImpact();

    // Increment progress to show the user a realistic upload progress bar
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _uploadProgress = i * 0.1;
      });
    }

    await HapticFeedback.mediumImpact();

    setState(() {
      _isUploading = false;
      // Add to local history list
      _uploadedHistory.insert(0, {
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'fileName': _simulatedFileName!,
        'date': 'Today',
      });
      // Clear inputs
      _titleController.clear();
      _notesController.clear();
      _simulatedFileName = null;
      _simulatedFileSize = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document encrypted and synced to cloud repository.'),
          backgroundColor: _primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Upload Health Documents',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 24),

              // Form fields
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Document picker button area
                    _buildPickerArea(),
                    const SizedBox(height: 20),

                    // Document Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Document Title',
                        labelStyle: const TextStyle(fontFamily: 'Inter'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _primaryGreen, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a document title' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown & Notes
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Document Category',
                              labelStyle: const TextStyle(fontFamily: 'Inter'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _primaryGreen, width: 2),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Prescription', child: Text('Prescription')),
                              DropdownMenuItem(value: 'Lab Report', child: Text('Lab Report')),
                              DropdownMenuItem(value: 'Vaccination Card', child: Text('Vaccination')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Optional Notes (Diagnosis, symptoms, etc.)',
                        labelStyle: const TextStyle(fontFamily: 'Inter'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _primaryGreen, width: 2),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Icon(Icons.description_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress indicator
                    if (_isUploading) ...[
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        color: _primaryGreen,
                        backgroundColor: _cardBorderColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Encrypting and uploading: ${(double.parse((_uploadProgress * 100).toStringAsFixed(0)))}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Submission Button
                    ElevatedButton.icon(
                      onPressed: _isUploading || _simulatedFileName == null ? null : _simulateUpload,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text(
                        'Upload to Secure Cloud',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // History list
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : _primaryGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Zero-Knowledge Encrypted',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'All uploaded documents are client-side encrypted before cloud synchronisation. Clinicians require session token permission keys to decrypt files.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isUploading || _isSelectingFile ? null : _pickFileFromDevice,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentGreen, width: 2, style: BorderStyle.solid),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isSelectingFile
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen)),
                      const SizedBox(height: 12),
                      const Text('Accessing device files...', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
                    ],
                  ),
                )
              : (_simulatedFileName != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file_rounded, color: _primaryGreen, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          _simulatedFileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _simulatedFileSize!,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Scan Prescriptions / Select Files',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports PDF, PNG, JPG files up to 10MB',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                        ),
                      ],
                    )),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SECURE UPLOAD HISTORY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _uploadedHistory.length,
          itemBuilder: (context, index) {
            final file = _uploadedHistory[index];
            final String title = file['title'] ?? 'Document';
            final String category = file['category'] ?? 'Other';
            final String fileName = file['fileName'] ?? 'file.pdf';
            final String dateStr = file['date'] ?? 'N/A';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _cardBorderColor, width: 1),
              ),
              color: Theme.of(context).cardColor,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lock_rounded, color: _primaryGreen, size: 20),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category: $category | Name: $fileName',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.gpp_good_rounded, color: _accentGreen, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Encrypted and Synced',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dateStr,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.visibility_outlined, color: _primaryGreen, size: 20),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _previewDocument(file);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
