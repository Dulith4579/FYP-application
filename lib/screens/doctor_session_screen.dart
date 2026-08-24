import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';
import '../services/clinical_ai_service.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/medical_timeline_card.dart';

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
  
  // Dynamic session ID updated per session reset
  late String _sessionId;

  // AI Clinical History Summarizer states
  String? _historySummary;
  bool _isGeneratingSummary = false;
  String? _summaryError;
  
  // Next Clinic Date scheduled from the doctor/clinical institution side
  DateTime? _nextClinicDate;

  // Colors mapping the Clinical Green theme (dynamic for dark mode compatibility)
  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
  Color get _accentGreen => const Color(0xFF4CAF50);
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _darkGrey => Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF37474F);
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9);

  String _selectedPatientId = '';
  String? _lastDecryptedSessionKey;

  // Stream caching properties to prevent lag/reconnect loops during parent state rebuilds
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _sessionStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _timelineStream;
  String? _timelineStreamPatientId;

  // Active patient drug allergies / ADRs and warning state
  List<Map<String, String>> _activePatientAdrs = [];
  String? _allergyWarningMessage;

  // Speech-to-text integration properties
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _speechStatus = '';

  @override
  void initState() {
    super.initState();
    // Initialize defaults to make the demo presentation smooth
    _conditionController.text = 'Type 2 Diabetes Mellitus';
    _medicationController.text = 'Metformin Hydrochloride 500mg';
    _dosageController.text = '1 tablet twice daily';
    _notesController.text = 'Monitor fasting blood glucose levels daily. Maintain low glycaemic diet.';
    
    _generateSessionId();
    _medicationController.addListener(_checkPrescriptionSafety);
    
    // Ensure the session is initialized in Firestore when the screen loads
    _resetSessionState();

    // Initialize Doctor RSA cryptographic keys
    _initDoctorCryptographicKeys();
  }

  Future<void> _initDoctorCryptographicKeys() async {
    final docUser = AuthService.instance.currentUser;
    if (docUser != null && docUser.role == 'doctor') {
      try {
        await FirebasePhrService.instance.initializeDoctorKeys(docUser.uid);
      } catch (e) {
        debugPrint('Error generating doctor RSA keys: $e');
      }
    }
  }

  void _checkPrescriptionSafety() {
    final typedDrug = _medicationController.text.trim().toLowerCase();
    if (typedDrug.isEmpty || _activePatientAdrs.isEmpty) {
      if (_allergyWarningMessage != null) {
        setState(() {
          _allergyWarningMessage = null;
        });
      }
      return;
    }

    String? matchedAllergy;
    for (var adr in _activePatientAdrs) {
      final allergen = adr['drugName']!.toLowerCase().trim();
      if (allergen.isNotEmpty && typedDrug.contains(allergen)) {
        matchedAllergy = adr['drugName'];
        break;
      }
    }

    if (matchedAllergy != null) {
      final msg = "ALLERGY WARNING: Patient has a documented suspected allergy/ADR to '$matchedAllergy'!";
      if (_allergyWarningMessage != msg) {
        setState(() {
          _allergyWarningMessage = msg;
        });
      }
    } else {
      if (_allergyWarningMessage != null) {
        setState(() {
          _allergyWarningMessage = null;
        });
      }
    }
  }

  Widget _buildVitalColumn(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _speech.stop();
      return;
    }

    setState(() {
      _speechStatus = 'Initializing mic...';
    });

    try {
      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (val == 'notListening' || val == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint('Speech error: $val');
          setState(() {
            _isListening = false;
            _speechStatus = 'Error: ${val.errorMsg}';
          });
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _speechStatus = 'Listening... Speak now.';
        });
        await _speech.listen(
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
              setState(() {
                _aiShorthandController.text = val.recognizedWords;
              });
            }
          },
        );
      } else {
        setState(() {
          _speechStatus = 'Speech recognition not available. Simulating...';
        });
        _simulateSpeechInput();
      }
    } catch (e) {
      setState(() {
        _speechStatus = 'Permission blocked. Simulating...';
      });
      _simulateSpeechInput();
    }
  }

  void _simulateSpeechInput() {
    const simulatedNote = 'Patient dry cough, chest tightness. Rx: Amoxicillin 500mg, avoid taking with food.';
    
    setState(() {
      _isListening = true;
    });
    
    int index = 0;
    _aiShorthandController.clear();
    Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (index < simulatedNote.length && _isListening) {
         _aiShorthandController.text += simulatedNote[index];
         index++;
      } else {
        timer.cancel();
        setState(() {
          _isListening = false;
          _speechStatus = 'Dictation completed (Simulated).';
        });
      }
    });
  }

  void _decryptAndSetActiveKey(String encryptedAesKey) async {
    if (_lastDecryptedSessionKey == encryptedAesKey) return;
    _lastDecryptedSessionKey = encryptedAesKey;
    
    try {
      final docUser = AuthService.instance.currentUser;
      if (docUser != null) {
        final decryptedKey = await FirebasePhrService.instance.decryptSessionKey(docUser.uid, encryptedAesKey);
        EncryptionService.setActiveKey(decryptedKey);
        
        // Log an access audit log for data view
        await FirebasePhrService.instance.logAudit(
          actorId: docUser.uid,
          actorRole: 'doctor',
          action: 'VIEWED_RECORDS',
          details: 'E2EE Decryption key handshake completed. Clinician viewed patient records.',
          patientId: _selectedPatientId,
          sessionId: _sessionId,
        );
      }
    } catch (e) {
      debugPrint("Failed to decrypt patient E2EE key: $e");
    }
  }

  void _generateSessionId() {
    _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _medicationController.removeListener(_checkPrescriptionSafety);
    _conditionController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _aiShorthandController.dispose();
    super.dispose();
  }

  Future<void> _resetSessionState() async {
    setState(() {
      _generateSessionId();
      _isDemoAuthorized = false;
      _isDemoClosed = false;
      _historySummary = null;
      _summaryError = null;
      _selectedPatientId = '';
      _lastDecryptedSessionKey = null;
      _timelineStream = null;
      _timelineStreamPatientId = null;
      _sessionStream = FirebasePhrService.instance.getSessionStream(_sessionId);
    });
    if (Firebase.apps.isEmpty) {
      return;
    }
    final docUser = AuthService.instance.currentUser;
    final docUid = docUser?.uid ?? 'unknown_doctor';
    unawaited(FirebasePhrService.instance
        .resetSession(_sessionId, docUid, widget.doctorName, widget.license)
        .timeout(const Duration(seconds: 2))
        .catchError((e) {
      debugPrint('Error resetting session: $e');
    }));
  }

  /// Calls the local Ollama LLM to synthesize the patient's decrypted past records.
  Future<void> _generateHistorySummary(List<MedicalLog> logs) async {
    setState(() {
      _isGeneratingSummary = true;
      _summaryError = null;
    });

    try {
      final concatenatedHistory = logs.map((l) {
        final dateStr = "${l.timestamp.day}/${l.timestamp.month}/${l.timestamp.year}";
        return "Record Date: $dateStr. Condition: ${l.clinical.condition}. Medication: ${l.clinical.medication}. Dosage: ${l.clinical.dosage}. Notes: ${l.clinical.notes}.";
      }).join('\n');

      final result = await ClinicalAiService.instance.analyzePatientHistoryForDoctor(concatenatedHistory);
      setState(() {
        _historySummary = result.plainSummaryTranslations;
      });
    } catch (e) {
      setState(() {
        _summaryError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isGeneratingSummary = false;
      });
    }
  }

  /// Saves the clinical log to Firestore, closes the session, and triggers a state refresh.
  Future<void> _submitClinicalLog(String patientId, String patientName) async {
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
          SnackBar(
            content: const Text('Demo Mode: Mock Diagnosis Log submitted successfully.'),
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
        patientName: patientName,
        condition: _conditionController.text.trim(),
        medication: _medicationController.text.trim(),
        dosage: _dosageController.text.trim(),
        notes: _notesController.text.trim(),
        doctorName: widget.doctorName,
        license: widget.license,
        doctorUid: AuthService.instance.currentUser?.uid ?? 'unknown_doctor',
      );
      
      // 2. Schedule Next Clinic Date in patient's appointments if set
      if (_nextClinicDate != null) {
        await FirebasePhrService.instance.requestAppointment(
          patientId: patientId,
          doctorName: widget.doctorName,
          specialty: 'Clinical Consult',
          facilityName: 'Colombo General Hospital',
          isGovernmentHospital: true,
          dateTime: _nextClinicDate!,
        );
      }

      // 3. Set session status to 'closed' to revoke access and complete the security protocol
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_sessionId)
          .update({'status': 'closed'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Diagnosis Log submitted. Session secured and closed.'),
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
          SnackBar(
            content: const Text('AI draft parsed and loaded for review!'),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : _primaryGreen,
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Firebase.apps.isEmpty
            ? (_isDemoClosed
                ? _buildSessionClosedView()
                : (_isDemoAuthorized
                    ? _buildClinicianInputForm('patient_014172', 'Full Longitudinal History Access', 'Dulith Chandira')
                    : _buildAwaitingAuthView()))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _sessionStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data?.data();
                  final String status = data?['status'] ?? 'pending';
                  final String patientId = data?['patientId'] ?? '';
                  final String accessLevel = data?['accessLevel'] ?? '';
                  final String patientName = data?['patientName'] ?? 'Dulith Chandira';
                  final String encryptedAesKey = data?['encryptedAesKey'] ?? '';

                  // Layout states depending on patient authorization status
                  if (status == 'authorized' && patientId.isNotEmpty) {
                    _selectedPatientId = patientId;
                    if (encryptedAesKey.isNotEmpty) {
                      _decryptAndSetActiveKey(encryptedAesKey);
                    }
                    return _buildClinicianInputForm(patientId, accessLevel, patientName);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              side: BorderSide(color: _cardBorderColor),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _primaryGreen.withOpacity(0.1),
                    child: Icon(Icons.medical_services_rounded, color: _primaryGreen),
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
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _cardBorderColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Text(
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
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Session QR Code representation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, // High contrast white background for scanner clarity
                      border: Border.all(color: _primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: 'phr://session/$_sessionId',
                      version: QrVersions.auto,
                      size: 220,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Session ID: $_sessionId',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Connection status loader
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
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
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
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
  Widget _buildClinicianInputForm(String patientId, String accessLevel, String patientName) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Patient History Section
          Expanded(
            flex: 5,
            child: _buildPatientHistorySection(patientId, accessLevel),
          ),
          VerticalDivider(
            width: 1, 
            thickness: 1, 
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300]
          ),
          // Right side: Active form entry and note assistant
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: _buildFormContent(patientId, accessLevel, patientName),
            ),
          ),
        ],
      );
    } else {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // For mobile viewports, wrap history in an expansion panel or direct stacked view
            _buildPatientHistorySection(patientId, accessLevel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300]
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildFormContent(patientId, accessLevel, patientName),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFormContent(String patientId, String accessLevel, String patientName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
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
                    children: [
                      Icon(Icons.lock_open_rounded, color: _primaryGreen),
                      const SizedBox(width: 8),
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
                    'Authorized Patient: $patientName',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _darkGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'User ID: $patientId',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  Text(
                    'Scope granted: $accessLevel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: _primaryGreen, size: 20),
                      const SizedBox(width: 8),
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
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                      fillColor: isDark ? Colors.grey[900] : const Color(0xFFFAFAFA),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Voice-to-Text Button
                      TextButton.icon(
                        onPressed: _toggleListening,
                        icon: Icon(
                          _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: _isListening ? Colors.redAccent : _primaryGreen,
                          size: 18,
                        ),
                        label: Text(
                          _isListening ? 'Stop dictating' : 'Voice Dictate',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _isListening ? Colors.redAccent : _primaryGreen,
                          ),
                        ),
                      ),
                      
                      // Status label
                      if (_speechStatus.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              _speechStatus,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: _isListening ? Colors.redAccent : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),

                      // Parse Shorthand button
                      ElevatedButton.icon(
                        onPressed: _isAiParsing || _isListening ? null : _handleAiParse,
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
                          _isAiParsing ? 'Parsing...' : 'AI Parse',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
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
                  color: isDark ? Colors.amber.withOpacity(0.15) : Colors.amber[50],
                  border: Border.all(color: isDark ? Colors.amber[800]! : Colors.amber[300]!, width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: isDark ? Colors.amber[300] : Colors.amber[800], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Draft Loaded - Please Review & Verify Below',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.amber[300] : Colors.amber[800], size: 14),
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
                    color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50],
                    border: Border.all(color: isDark ? Colors.red[800]! : Colors.red[200]!, width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: isDark ? Colors.red[300] : Colors.red[800], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'AI Safety Warning',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark ? Colors.red[200] : Colors.red[900],
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
                          color: isDark ? Colors.red[100] : Colors.red[950],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            Text(
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
                helperStyle: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.healing, color: _primaryGreen),
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
                helperStyle: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.medication, color: _primaryGreen),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter medication' : null,
            ),
            const SizedBox(height: 16),
            if (_allergyWarningMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50]?.withOpacity(isDark ? 0.15 : 1.0),
                  border: Border.all(color: Colors.redAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _allergyWarningMessage!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _dosageController,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Dosage / Frequencies',
                helperText: _activeDraft != null ? 'AI Draft - Please review' : null,
                helperStyle: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.repeat, color: _primaryGreen),
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
                helperStyle: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 11),
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes, color: _primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Next Clinic Date Selection Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _cardBorderColor),
              ),
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCHEDULE NEXT CLINIC VISIT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: _darkGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _nextClinicDate == null
                                ? 'No next clinic date scheduled'
                                : 'Next Date: ${_nextClinicDate!.day}/${_nextClinicDate!.month}/${_nextClinicDate!.year}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              fontWeight: _nextClinicDate == null ? FontWeight.normal : FontWeight.bold,
                              color: _nextClinicDate == null ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(_nextClinicDate == null ? 'Schedule' : 'Change'),
                          style: TextButton.styleFrom(foregroundColor: _primaryGreen),
                          onPressed: () async {
                            final dt = await showDatePicker(
                              context: context,
                              initialDate: _nextClinicDate ?? DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (dt != null) {
                              setState(() {
                                _nextClinicDate = dt;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: _primaryGreen, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This will notify the patient dashboard of their next clinic appointment.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submission Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitClinicalLog(patientId, patientName),
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
      );
    }

  /// Fallback view shown when the session ends or is reset.
  Widget _buildSessionClosedView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 64, color: _primaryGreen),
            const SizedBox(height: 16),
            Text(
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
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetSessionState,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bgColor,
                foregroundColor: _primaryGreen,
                elevation: 0,
                side: BorderSide(color: _primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open New Diagnostic Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHistorySection(String patientId, String accessLevel) {
    if (_timelineStream == null || _timelineStreamPatientId != patientId) {
      _timelineStreamPatientId = patientId;
      _timelineStream = FirebasePhrService.instance.getMedicalTimeline(patientId);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWriteOnly = accessLevel == 'New Diagnosis Logs Entry Only';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _timelineStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No past health records found for this patient.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data!.docs
            .map((doc) => MedicalLog.fromJson(doc.data()))
            .toList();
        final displayLogs = logs.take(10).toList();

        final Widget historyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drug Allergies & ADR Alerts Section
            _buildAdrsWarningSection(patientId),

            // AI History Summary Panel
            _buildHistoryAiSummaryCard(displayLogs),
            const SizedBox(height: 24),

            Text(
              'PAST CLINICAL RECORDS (Showing ${displayLogs.length} of ${logs.length})',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = displayLogs[index];
                return _buildPastRecordItemCard(log);
              },
            ),
          ],
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PATIENT LONGITUDINAL HISTORY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              if (isWriteOnly)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        foregroundDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: IgnorePointer(
                          child: historyContent,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.9),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Longitudinal History Locked',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Patient granted Write-Only access. Past records are hidden.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                           ElevatedButton.icon(
                            onPressed: () async {
                              if (Firebase.apps.isNotEmpty) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('sessions')
                                      .doc(_sessionId)
                                      .update({'status': 'requesting_upgrade'});
                                } catch (e) {
                                  debugPrint('Error updating session request: $e');
                                }
                              }
                              
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Theme.of(context).cardColor,
                                    title: Row(
                                      children: [
                                        Icon(Icons.vpn_key_rounded, color: _primaryGreen),
                                        const SizedBox(width: 8),
                                        const Text('Request Access', style: TextStyle(fontFamily: 'Outfit')),
                                      ],
                                    ),
                                    content: const Text(
                                      'A secure cryptographic request for Full Longitudinal History access has been sent to the patient\'s device.\n\nOnce they approve the request, this view will automatically unlock.',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.4),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('OK', style: TextStyle(color: _primaryGreen)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.security, size: 14),
                            label: const Text('Request Full Access'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                historyContent,
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryAiSummaryCard(List<MedicalLog> logs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(0.06),
        border: Border.all(color: _primaryGreen.withOpacity(0.2), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_rounded, color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Clinical History Summary',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_historySummary == null) ...[
            Text(
              'No summary generated yet. Generate an AI summary to scan all longitudinal records instantly.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isGeneratingSummary ? null : () => _generateHistorySummary(logs),
              icon: _isGeneratingSummary
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.flash_on, size: 14),
              label: Text(_isGeneratingSummary ? 'Analyzing records...' : 'Generate AI History Summary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            Text(
              _historySummary!,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4, color: isDark ? Colors.grey[200] : Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _isGeneratingSummary ? null : () => _generateHistorySummary(logs),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Re-generate Summary'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryGreen,
              ),
            ),
          ],
          if (_summaryError != null) ...[
            const SizedBox(height: 8),
            Text(
              'AI Summary Error: $_summaryError',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastRecordItemCard(MedicalLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = "${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}";
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  log.doctor.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _primaryGreen,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              log.clinical.condition,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (log.clinical.medication.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Prescribed: ${log.clinical.medication} (${log.clinical.dosage})',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
            if (log.clinical.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Notes: ${log.clinical.notes}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdrsWarningSection(String patientId) {
    if (Firebase.apps.isEmpty) {
      // In offline/demo mode, use mock ADRs for Penicillin, Metformin, Aspirin
      _activePatientAdrs = [
        {'drugName': 'Penicillin', 'reaction': 'Allergic skin rashes (Urticaria)'},
        {'drugName': 'Metformin', 'reaction': 'Severe gastrointestinal cramps'},
        {'drugName': 'Aspirin', 'reaction': 'Gastric mucosal irritation & acidity'},
      ];
      return _buildAdrsCard(_activePatientAdrs);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePhrService.instance.getAdrs(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data?.docs;
        if (docs == null || docs.isEmpty) {
          _activePatientAdrs = [];
          return const SizedBox.shrink();
        }

        _activePatientAdrs = docs.map((d) {
          final data = d.data();
          return {
            'drugName': data['drugName'] as String? ?? '',
            'reaction': data['reaction'] as String? ?? '',
          };
        }).toList();

        return _buildAdrsCard(_activePatientAdrs);
      },
    );
  }

  Widget _buildAdrsCard(List<Map<String, String>> adrs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      color: Colors.red[50]?.withOpacity(isDark ? 0.1 : 1.0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'CRITICAL DRUG ALLERGY WARNINGS',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...adrs.map((adr) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: '${adr['drugName']}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: adr['reaction']),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

