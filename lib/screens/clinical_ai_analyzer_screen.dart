import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/clinical_ai_service.dart';

/// Stateful screen for local AI-based Clinical Translation and Summarization.
/// 
/// Allows users/doctors to input messy OPD notes and translates/summarizes
/// them using a local Gemma 2 (2B) model running via Ollama.
class ClinicalAiAnalyzer extends StatefulWidget {
  const ClinicalAiAnalyzer({super.key});

  @override
  State<ClinicalAiAnalyzer> createState() => _ClinicalAiAnalyzerState();
}

class _ClinicalAiAnalyzerState extends State<ClinicalAiAnalyzer> {
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  ClinicalAnalysisResult? _analysisResult;
  String? _errorMessage;

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
    });

    await HapticFeedback.mediumImpact();

    try {
      final result = await ClinicalAiService.instance.analyzeOpdNotes(rawInput);
      if (mounted) {
        setState(() {
          _analysisResult = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Clinical notes analyzed successfully!'),
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
          'Local AI Clinical Translator',
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
                  'Local Gemma 2 Summarization Engine',
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
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
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
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
