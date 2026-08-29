import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/clinical_ai_service.dart';
import '../services/firebase_phr_service.dart';
import '../widgets/medical_timeline_card.dart';
import '../services/translation_service.dart';

/// Stateful screen for local AI-based Clinical Translation and Summarization.
/// 
/// Allows users/doctors to input messy OPD notes and translates/summarizes
/// them using a local Gemma 2 (2B) model running via Ollama.
class ClinicalAiAnalyzer extends StatefulWidget {
  final String? patientId;
  const ClinicalAiAnalyzer({super.key, this.patientId});

  @override
  State<ClinicalAiAnalyzer> createState() => _ClinicalAiAnalyzerState();
}

class _ClinicalAiAnalyzerState extends State<ClinicalAiAnalyzer> {
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  ClinicalAnalysisResult? _analysisResult;
  String? _errorMessage;

  String? _translatedSi;
  String? _translatedTa;
  bool _isTranslating = false;

  // Design system constants (dynamic for dark mode)
  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9);

  @override
  void dispose() {
    _notesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Triggers the API request to local Ollama.
  Future<void> _analyzeRecord() async {
    final rawInput = _notesController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter clinical notes to analyze.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysisResult = null;
      _translatedSi = null;
      _translatedTa = null;
      _isTranslating = false;
    });

    await HapticFeedback.mediumImpact();

    try {
      final result = await ClinicalAiService.instance.analyzeOpdNotes(rawInput);
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isTranslating = true;
        });

        // Trigger Google Cloud Translation for Sinhala and Tamil
        final plainText = result.plainSummaryTranslations;
        final siTranslation = await TranslationService.translate(plainText, 'si');
        final taTranslation = await TranslationService.translate(plainText, 'ta');

        if (mounted) {
          setState(() {
            _translatedSi = siTranslation;
            _translatedTa = taTranslation;
            _isTranslating = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Clinical notes analyzed and translated successfully!'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to connect to local Ollama server. Verify it is running.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[850],
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _analyzeRecord,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          'AI Clinical Translator',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              _buildFeatureOverviewCard(),
              const SizedBox(height: 20),

              // Visit Selector Dropdown
              _buildVisitSelector(),

              // Input Card
              _buildInputCard(),
              const SizedBox(height: 24),

              // Results or States Container
              const Text(
                'CLINICAL INSIGHTS & TRANSLATIONS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildOutputSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureOverviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(0.06),
        border: Border.all(color: _cardBorderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology,
              color: _primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gemma 2 Summarization Engine',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This feature runs locally on your device via Ollama. It does not transmit patient medical records to external web servers, preserving healthcare confidentiality.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.3,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Raw Medical History Input',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter raw outpatient department (OPD) summaries, prescriptions, or clinical notes.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _notesController,
            focusNode: _focusNode,
            maxLines: 6,
            minLines: 3,
            maxLength: 800,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., Pt c/o fever since 3 days, cough, chest tightness. Rx: Amoxicillin 500mg TDS x 5d, Paracetamol 1g QDS PRN.',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              labelText: 'Messy Medical History / Notes',
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.description_outlined, color: Colors.grey),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryGreen, width: 1.8),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : const Color(0xFFFAFAFA),
            ),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _analyzeRecord,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.flash_on_rounded, color: Colors.white),
            label: Text(
              _isLoading ? 'Processing Clinical Data...' : 'Analyze Record',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
              ),
              const SizedBox(height: 20),
              Text(
                'Generating Trilingual Summary...',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ollama Gemma 2 is processing the text and generating translation layers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.red[800]! : Colors.red[200]!, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.red[800], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ollama Connection Offline',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Please verify the local AI server state:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Ensure Ollama is running on your host machine.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Verify model is pre-installed: "ollama pull gemma2:2b"',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Verify the host is listening on port 11434.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 6),
                      Text(
                        '• CORS Policy: Web browsers block local API requests unless Ollama is started with CORS allowed. Set OLLAMA_ORIGINS in your terminal:',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Windows PowerShell:\n\$env:OLLAMA_ORIGINS="*"\nollama serve\n\nCMD:\nset OLLAMA_ORIGINS=*\nollama serve',
                          style: TextStyle(fontFamily: 'Courier', fontSize: 10.5, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Details: $_errorMessage',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _analyzeRecord,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_analysisResult == null) {
      return Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.insights_outlined,
                size: 60,
                color: _primaryGreen.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Awaiting Clinical Input',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter raw clinician notes above to translate terms, extract diagnostics, and generate summaries.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Results display
    final result = _analysisResult!;
    return Column(
      children: [
        // Active Model Status Indicator Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: result.isFineTuned
                ? (isDark ? Colors.green[900]!.withOpacity(0.4) : Colors.green[50])
                : (isDark ? Colors.amber[900]!.withOpacity(0.4) : Colors.amber[50]),
            border: Border.all(
              color: result.isFineTuned ? Colors.green : Colors.amber[700]!,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                result.isFineTuned ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 16,
                color: result.isFineTuned ? Colors.green : Colors.amber[800],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inference Model Used: ${result.modelUsed}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: result.isFineTuned
                        ? (isDark ? Colors.green[200] : Colors.green[900])
                        : (isDark ? Colors.amber[200] : Colors.amber[900]),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 1. Extracted Conditions Card
        _buildResultCard(
          title: '1. Extracted Conditions',
          icon: Icons.healing_rounded,
          color: _primaryGreen,
          content: result.extractedConditions,
        ),
        const SizedBox(height: 16),

        // 2. Active Prescriptions Card
        _buildResultCard(
          title: '2. Active Prescriptions',
          icon: Icons.medication_rounded,
          color: isDark ? Colors.teal[300]! : Colors.teal[700]!,
          content: result.activePrescriptions,
        ),
        const SizedBox(height: 16),

        // 3. Translations & Summaries Card
        _buildResultCard(
          title: '3. Plain-Language Summary & Translations',
          icon: Icons.g_translate_rounded,
          color: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
          content: result.plainSummaryTranslations,
          translatedSi: _translatedSi,
          translatedTa: _translatedTa,
          isTranslating: _isTranslating,
        ),
      ],
    );
  }

  Widget _buildVisitSelector() {
    if (widget.patientId == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePhrService.instance.getMedicalTimeline(widget.patientId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Recent Consultation Visit to Explain',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : const Color(0xFFFAFAFA),
                ),
                dropdownColor: Theme.of(context).cardColor,
                hint: const Text(
                  'Choose a clinical record...',
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                items: docs.map((doc) {
                  final data = doc.data();
                  final log = MedicalLog.fromJson(data);
                  final dateStr = "${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}";
                  return DropdownMenuItem<String>(
                    value: log.logId,
                    child: Text(
                      "$dateStr: ${log.clinical.condition} (by ${log.doctor.name})",
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                    ),
                  );
                }).toList(),
                onChanged: (logId) {
                  if (logId == null) return;
                  final doc = docs.firstWhere((d) => d.id == logId);
                  final log = MedicalLog.fromJson(doc.data());
                  // Decrypt and populate notes
                  final textToPopulate = "Condition: ${log.clinical.condition}. Medication: ${log.clinical.medication}. Dosage: ${log.clinical.dosage}. Notes: ${log.clinical.notes}.";
                  _notesController.text = textToPopulate;
                  // Auto trigger analysis
                  _analyzeRecord();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
    String? translatedSi,
    String? translatedTa,
    bool isTranslating = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: color.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (translatedSi != null || translatedTa != null || isTranslating) ...[
                    Text(
                      'English Explanation',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (translatedSi != null || translatedTa != null || isTranslating) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                  ],
                  if (isTranslating)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Translating into Sinhala & Tamil...',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (translatedSi != null) ...[
                      Text(
                        'සිංහල පරිවර්තනය (Sinhala)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        translatedSi,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                    if (translatedTa != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'தமிழ் மொழிபெயர்ப்பு (Tamil)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        translatedTa,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
