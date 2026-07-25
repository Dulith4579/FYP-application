import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';
import '../services/clinical_ai_service.dart';

/// Clinician Session Screen representing the Doctor's Desktop/Terminal interface.
/// 
/// Facilitates real-time patient-doctor session bindings. Shows the diagnostic QR,
/// listens for patient authorization, and provides a clinical form to log new diagnoses.
class DoctorSessionScreen extends StatefulWidget {
  final String sessionId;
  final String doctorName;
  final String license;

  const DoctorSessionScreen({
    super.key,
    this.sessionId = 'session_9941A',
    this.doctorName = 'Dr. Ruwan Gunawardena',
    this.license = 'SLMC-8829',
  });

  @override
  State<DoctorSessionScreen> createState() => _DoctorSessionScreenState();
}

class _DoctorSessionScreenState extends State<DoctorSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form input controllers
  final _conditionController = TextEditingController();
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  // AI Shorthand notes parser controllers and state
  final _aiShorthandController = TextEditingController();
  bool _isAiParsing = false;
  PrescriptionDraft? _activeDraft;
  String? _aiError;

  bool _isSubmitting = false;

  // Local state flags for unconfigured Firestore instances
  bool _isDemoAuthorized = false;
  bool _isDemoClosed = false;

  // Colors mapping the Clinical Green theme
  static const Color _primaryGreen = Color(0xFF1B5E20);   // Deep Forest Green
  static const Color _accentGreen = Color(0xFF4CAF50);    // Mint Green
  static const Color _bgColor = Color(0xFFF5F7F5);        // Clean Light Slate/Grey
  static const Color _darkGrey = Color(0xFF37474F);
  static const Color _cardBorderColor = Color(0xFFC8E6C9);

  @override
  void initState() {
    super.initState();
    // Initialize defaults to make the demo presentation smooth
    _conditionController.text = 'Type 2 Diabetes Mellitus';
    _medicationController.text = 'Metformin Hydrochloride 500mg';
    _dosageController.text = '1 tablet twice daily';
    _notesController.text = 'Monitor fasting blood glucose levels daily. Maintain low glycaemic diet.';
    
    // Ensure the session is initialized in Firestore when the screen loads
    _resetSessionState();
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _aiShorthandController.dispose();
    super.dispose();
  }

  /// Resets the current session back to a pending state in Firestore.
  Future<void> _resetSessionState() async {
    if (Firebase.apps.isEmpty) {
      setState(() {
        _isDemoAuthorized = false;
        _isDemoClosed = false;
      });
      return;
    }
    try {
      await FirebasePhrService.instance.resetSession(widget.sessionId);
    } catch (e) {
      debugPrint('Error resetting session: $e');
    }
  }

  /// Saves the clinical log to Firestore, closes the session, and triggers a state refresh.
  Future<void> _submitClinicalLog(String patientId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    await HapticFeedback.mediumImpact();

    if (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isDemoAuthorized = false;
          _isDemoClosed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo Mode: Mock Diagnosis Log submitted successfully.'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
      return;
    }

    try {
      // 1. Submit diagnostic log to patient's medical timeline
      await FirebasePhrService.instance.submitDiagnosisLog(
        patientId: patientId,
        condition: _conditionController.text.trim(),
        medication: _medicationController.text.trim(),
        dosage: _dosageController.text.trim(),
        notes: _notesController.text.trim(),
        doctorName: widget.doctorName,
        license: widget.license,
      );

      // 2. Set session status to 'closed' to revoke access and complete the security protocol
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .update({'status': 'closed'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diagnosis Log submitted. Session secured and closed.'),
            backgroundColor: _primaryGreen,
          ),
        );
        // Clear inputs for next session
        _conditionController.clear();
        _medicationController.clear();
        _dosageController.clear();
        _notesController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Sends shorthand notes to Ollama to parse into a verified local draft.
  Future<void> _handleAiParse() async {
    final note = _aiShorthandController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter shorthand notes for the AI to parse.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isAiParsing = true;
      _aiError = null;
      _activeDraft = null;
    });

    await HapticFeedback.mediumImpact();

    try {
      final draft = await ClinicalAiService.instance.parseShorthandNote(note);
      if (mounted) {
        setState(() {
          _activeDraft = draft;
          _conditionController.text = draft.condition;
          _medicationController.text = draft.medication;
          _dosageController.text = draft.dosage;
          _notesController.text = draft.notes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI draft parsed and loaded for review!'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.toString().replaceFirst('Exception: ', '');
          // Fall back to empty draft structure so form remains fully editable
          _activeDraft = PrescriptionDraft.empty();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Local AI parsing failed: $_aiError. Input remains editable.'),
            backgroundColor: Colors.red[850],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiParsing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Clinician Session Console',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Session Key',
            onPressed: _resetSessionState,
          ),
        ],
      ),
      body: SafeArea(
        child: Firebase.apps.isEmpty
            ? (_isDemoClosed
                ? _buildSessionClosedView()
                : (_isDemoAuthorized
                    ? _buildClinicianInputForm('patient_014172', 'Full Longitudinal History Access')
                    : _buildAwaitingAuthView()))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebasePhrService.instance.getSessionStream(widget.sessionId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data?.data();
                  final String status = data?['status'] ?? 'pending';
                  final String patientId = data?['patientId'] ?? '';
                  final String accessLevel = data?['accessLevel'] ?? '';

                  // Layout states depending on patient authorization status
                  if (status == 'authorized' && patientId.isNotEmpty) {
                    return _buildClinicianInputForm(patientId, accessLevel);
                  } else if (status == 'closed') {
              return _buildSessionClosedView();
            }

            // Default: Session pending, display QR key code
            return _buildAwaitingAuthView();
          },
        ),
      ),
    );
  }

  /// Screen displayed while doctor is waiting for patient to scan and authorize.
  Widget _buildAwaitingAuthView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Doctor Info Profile
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _cardBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _primaryGreen.withOpacity(0.1),
                    child: const Icon(Icons.medical_services_rounded, color: _primaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.doctorName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'SLMC Practitioner ID: ${widget.license}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Diagnostic session link card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _cardBorderColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const Text(
                    'Waiting for Patient Connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point the patient\'s camera scanner at this session code to link dashboards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Session QR Code representation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 220,
                      color: Colors.grey[850],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Connection status loader
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Awaiting patient authorization...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  if (Firebase.apps.isEmpty) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isDemoAuthorized = true;
                        });
                      },
                      icon: const Icon(Icons.flash_on, size: 16),
                      label: const Text('Bypass Scan (Simulate Patient Auth)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen displaying active clinical form once authorization matches 'authorized'.
  Widget _buildClinicianInputForm(String patientId, String accessLevel) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session authorization status box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.1),
                border: Border.all(color: _accentGreen, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_open_rounded, color: _primaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'Secure Diagnostic Session Linked',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Authorized User ID: $patientId',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _darkGrey,
                    ),
                  ),
                  Text(
                    'Scope granted: $accessLevel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI Note Assistant Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome_rounded, color: _primaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Consultation Note Assistant',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Input shorthand doctor notes. Gemma 2 will parse them into structured fields below.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiShorthandController,
                    maxLines: 3,
                    minLines: 2,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'e.g., Pt dry cough, chest tightness. Rx: Dextromethorphan 15mg TDS, warning: avoid taking with MAOIs.',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.grey[400],
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                      fillColor: const Color(0xFFFAFAFA),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isAiParsing ? null : _handleAiParse,
                    icon: _isAiParsing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.psychology, size: 16),
                    label: Text(
                      _isAiParsing ? 'Parsing notes with local AI...' : 'Parse Notes with AI',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_activeDraft != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[300]!, width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.amber[800], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Draft Loaded - Please Review & Verify Below',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.amber[800], size: 14),
                      onPressed: () {
                        setState(() {
                          _activeDraft = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
              ),
              if (_activeDraft!.warnings.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!, width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'AI Safety Warning',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.red[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeDraft!.warnings,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.red[950],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const Text(
              'LOG DIAGNOSIS & PRESCRIPTION',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _darkGrey,
              ),
            ),
            const SizedBox(height: 12),

            // Diagnostic Input Form Inputs
            TextFormField(
              controller: _conditionController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Diagnosed Condition',
                helperText: _activeDraft != null ? 'AI Draft - Please review' : null,
                helperStyle: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.healing),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter condition' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _medicationController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Prescribed Medication',
                helperText: _activeDraft != null ? 'AI Draft - Please review' : null,
                helperStyle: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.medication),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter medication' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _dosageController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Dosage / Frequencies',
                helperText: _activeDraft != null ? 'AI Draft - Please review' : null,
                helperStyle: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.repeat),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter dosage regimen' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Clinical Notes & Patient Instructions',
                helperText: _activeDraft != null ? 'AI Draft - Please review' : null,
                helperStyle: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submission Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitClinicalLog(patientId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Diagnosis Log & Close Session',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback view shown when the session ends or is reset.
  Widget _buildSessionClosedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 64, color: _primaryGreen),
            const SizedBox(height: 16),
            const Text(
              'Session Completed Successfully',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The medical logs have been uploaded. Cryptographic signature and trilingual AI translations are locked.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetSessionState,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bgColor,
                foregroundColor: _primaryGreen,
                elevation: 0,
                side: const BorderSide(color: _primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open New Diagnostic Session'),
            ),
          ],
        ),
      ),
    );
  }
}
