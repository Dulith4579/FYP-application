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
                    // Simulates decrypting and previewing file
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
