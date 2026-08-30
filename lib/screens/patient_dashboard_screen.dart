import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import '../widgets/patient_auth_bottom_sheet.dart';
import '../widgets/medical_timeline_card.dart';
import '../main.dart';
import 'doctor_session_screen.dart';
import 'clinical_ai_analyzer_screen.dart';
import '../widgets/audit_log_dialog.dart';
import '../widgets/metabolic_risk_calculator_card.dart';
import 'qr_scanner_screen.dart';

/// The central Patient Dashboard Screen for the AI-Based PHR System.
/// 
/// Serves as the primary landing hub for the patient, integrating live streams
/// for appointment scheduling and longitudinal medical log tracking.
class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  // Active patient profile context
  String _selectedPatientId = 'patient_014172';

  StreamSubscription? _upgradeRequestSubscription;
  bool _isUpgradeDialogOpen = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.activePatientNotifier.addListener(_onActivePatientChanged);
    _onActivePatientChanged();
  }

  void _onActivePatientChanged() {
    final activePatient = AuthService.instance.activePatientNotifier.value;
    final currentId = activePatient?.id ?? 'patient_014172';
    _listenForUpgradeRequests(currentId);
  }

  void _listenForUpgradeRequests(String patientId) {
    _upgradeRequestSubscription?.cancel();
    if (Firebase.apps.isEmpty) return;

    _upgradeRequestSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'requesting_upgrade')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final sessionId = doc.id;
            final doctorName = doc.data()['doctorName'] ?? 'Practitioner';
            _showUpgradeRequestDialog(sessionId, doctorName);
          }
        });
  }

  void _showUpgradeRequestDialog(String sessionId, String doctorName) {
    if (_isUpgradeDialogOpen) return;
    _isUpgradeDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: const [
            Icon(Icons.security_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Access Upgrade Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$doctorName is requesting Full Longitudinal History Access.\n\nThis will decrypt and share your past clinical records and conditions for diagnostic review. Do you want to grant full read access?',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _isUpgradeDialogOpen = false;
              
              try {
                await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                  'status': 'authorized',
                });
              } catch (e) {
                debugPrint('Error denying upgrade request: $e');
              }
            },
            child: const Text('Deny', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              _isUpgradeDialogOpen = false;

              try {
                await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                  'status': 'authorized',
                  'accessLevel': 'Full Longitudinal History Access',
                });
              } catch (e) {
                debugPrint('Error approving upgrade request: $e');
              }
            },
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AuthService.instance.activePatientNotifier.removeListener(_onActivePatientChanged);
    _upgradeRequestSubscription?.cancel();
    super.dispose();
  }

  // Local ADRs for offline fallback mode or local additions
  final List<Map<String, String>> _localAdrs = [
    {
      'id': 'adr_penicillin',
      'drugName': 'Penicillin',
      'reaction': 'Allergic skin rashes (Urticaria)',
    },
    {
      'id': 'adr_metformin',
      'drugName': 'Metformin',
      'reaction': 'Severe gastrointestinal cramps',
    },
    {
      'id': 'adr_aspirin',
      'drugName': 'Aspirin',
      'reaction': 'Gastric mucosal irritation & acidity',
    },
  ];

  // Set to track checked status of prescribed medications
  final Set<String> _checkedMeds = {};

  // Clinical Green Palette (dynamic for dark mode compatibility)
  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF81C784) 
      : const Color(0xFF1B5E20);
  Color get _accentGreen => const Color(0xFF4CAF50);
  Color get _bgColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF121212) 
      : const Color(0xFFF5F7F5);
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF2E7D32) 
      : const Color(0xFFC8E6C9);

  Future<void> _launchCameraScanner(String patientId) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      if (mounted) {
        PatientAuthBottomSheet.show(
          context: context,
          sessionId: result,
          patientId: patientId,
        );
      }
    }
  }

  /// Shows the generated QR connection code modal, allowing the patient to
  /// simulate scanning the doctor's reader and granting authorization.
  void _showQRGeneratorDialog(String patientId, String patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Authorization Key QR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: _primaryGreen,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your doctor scans this QR code to initiate the diagnostic session linking.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Visual QR Code Mock representation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: _primaryGreen, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 200,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[850],
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'Session ID: session_9941A',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            
            // Simulation trigger to open the bottom sheet
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Trigger the bottom sheet code we wrote in step 1
                PatientAuthBottomSheet.show(
                  context: context,
                  sessionId: 'session_9941A',
                  patientId: patientId,
                );
              },
              icon: const Icon(Icons.sensors, color: Colors.white),
              label: const Text('Simulate Scan (Open Auth Sheet)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// populates the Firestore database with sample entities for demonstration.
  Future<void> _initializeDatabaseData() async {
    try {
      await FirebasePhrService.instance.initializeMockData(_selectedPatientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Firestore database populated with sample PHR data.'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization Error: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivePatientProfile?>(
      valueListenable: AuthService.instance.activePatientNotifier,
      builder: (context, activePatient, _) {
        final currentId = activePatient?.id ?? 'patient_014172';
        final currentName = activePatient?.name ?? 'Dulith Chandira';
        final isDependent = activePatient?.isDependent ?? false;

        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).cardColor : _primaryGreen,
            elevation: 0,
            title: Text(
              isDependent ? 'Dependent PHR Portal' : 'My PHR Dashboard',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: Colors.white),
                tooltip: 'Security Access Logs',
                onPressed: () {
                  AuditLogDialog.show(context, currentId);
                },
              ),
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  themeNotifier.value = themeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await AuthService.instance.signOut();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileIndicatorBanner(currentName, isDependent),
                  _buildQRSection(currentId, currentName),
                  _buildAppointmentSection(currentId),
                  _buildAiAnalyzerCard(currentId),
                  const MetabolicRiskCalculatorCard(),
                  _buildTimelineSection(currentId),
                  _buildAnalyticsSection(currentId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileIndicatorBanner(String name, bool isDependent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDependent 
          ? (isDark ? Colors.amber[900]!.withOpacity(0.2) : Colors.amber[50])
          : (isDark ? Colors.grey[900] : Colors.grey[100]),
      child: Row(
        children: [
          Icon(
            isDependent ? Icons.family_restroom_rounded : Icons.account_circle_rounded,
            color: isDependent ? Colors.amber[800] : _primaryGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDependent 
                  ? 'Viewing profile: $name (Dependent Mode)'
                  : 'Active Account: $name (Main Account)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDependent 
                    ? (isDark ? Colors.amber[200] : Colors.amber[900])
                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ),
          if (isDependent)
            TextButton(
              onPressed: () {
                final user = AuthService.instance.currentUser;
                if (user != null) {
                  AuthService.instance.updateActivePatient(user.uid, user.displayName, false);
                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Switch back',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRSection(String patientId, String patientName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : const Color(0xFF1B5E20),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: isDark ? Border(bottom: BorderSide(color: _cardBorderColor, width: 1)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Personal Health Record Gateway',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share diagnostic timelines with healthcare practitioners securely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              // Main Camera Scanner Button
              Expanded(
                child: InkWell(
                  onTap: () => _launchCameraScanner(patientId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: isDark ? Colors.black87 : const Color(0xFF1B5E20),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scan Doctor QR',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.black87 : const Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Simulation / Demo Mode Generator Button
              Expanded(
                child: InkWell(
                  onTap: () => _showQRGeneratorDialog(patientId, patientName),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : const Color(0xFF81C784).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.sensors_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Simulate Scan',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentSection(String patientId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UPCOMING CONSULTATION',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text(
                  'Request',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showRequestAppointmentDialog(patientId),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (Firebase.apps.isEmpty)
            // Render the mock card directly for demo mode!
            _buildAppointmentCard(
              doctorName: 'Dr. Ruwan Gunawardena',
              specialty: 'Cardiologist (Demo Mode)',
              facility: 'Hemas Hospital',
              dateStr: 'Sunday, 28th June 2026 at 10:30 AM',
              appointmentDate: DateTime(2026, 6, 28),
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebasePhrService.instance.getNextAppointment(patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final data = snapshot.data?.data();
                if (snapshot.hasError || data == null) {
                  return _buildAppointmentFallback(
                    message: 'No upcoming appointments found in system database.',
                    showInit: true,
                    patientId: patientId,
                  );
                }

                final doctorName = data['doctorName'] ?? 'Practitioner';
                final specialty = data['specialty'] ?? '';
                final facility = data['facilityName'] ?? 'Hospital';
                final timestamp = data['dateTime'] as Timestamp?;
                final dateStr = timestamp != null
                    ? _formatAppointmentDate(timestamp.toDate())
                    : 'Pending Confirmation';

                return _buildAppointmentCard(
                  doctorName: doctorName,
                  specialty: specialty,
                  facility: facility,
                  dateStr: dateStr,
                  appointmentDate: timestamp?.toDate(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String doctorName,
    required String specialty,
    required String facility,
    required String dateStr,
    DateTime? appointmentDate,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 620;

    Widget appointmentDetails = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctorName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            specialty,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$dateStr\n@ $facility',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: _primaryGreen,
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor, width: 1.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: _primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  appointmentDetails,
                  if (appointmentDate != null) ...[
                    const SizedBox(width: 16),
                    _buildCalendarWidget(appointmentDate),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: _primaryGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      appointmentDetails,
                    ],
                  ),
                  if (appointmentDate != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Center(child: _buildCalendarWidget(appointmentDate)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCalendarWidget(DateTime appointmentDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = appointmentDate.year;
    final month = appointmentDate.month;
    
    final firstDay = DateTime(year, month, 1);
    final weekdayOfFirst = firstDay.weekday; // 1 (Mon) - 7 (Sun)
    final offset = weekdayOfFirst == 7 ? 0 : weekdayOfFirst; // offset if Sunday is column 0
    
    final daysCount = DateTime(year, month + 1, 0).day;
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final monthName = _getMonthName(month);

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Name Header
          Text(
            '$monthName $year',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Weekday Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) => Container(
              width: 20,
              alignment: Alignment.center,
              child: Text(
                day,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Days numbers list
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: offset + daysCount,
            itemBuilder: (context, index) {
              if (index < offset) {
                return const SizedBox.shrink();
              }
              final day = index - offset + 1;
              final isAppointmentDay = day == appointmentDate.day;

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isAppointmentDay ? _primaryGreen : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isAppointmentDay 
                      ? Border.all(color: Colors.white, width: 1)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: isAppointmentDay ? FontWeight.bold : FontWeight.normal,
                    color: isAppointmentDay 
                        ? Colors.white 
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildAiAnalyzerCard(String patientId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI CLINICAL TRANSLATOR',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorderColor, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClinicalAiAnalyzer(patientId: patientId)),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_outlined,
                          color: _primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Translate & Summarize Notes',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Convert messy clinical terms and descriptions into plain English, Sinhala, and Tamil.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(String patientId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'RECENT HEALTH TIMELINE ENTRY',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (Firebase.apps.isEmpty)
            // Render a mock card directly for demo mode!
            MedicalTimelineCard(
              log: MedicalLog(
                logId: 'log_889211',
                timestamp: DateTime.now().subtract(const Duration(days: 2)),
                doctor: DoctorMetadata(
                  name: 'Dr. Ruwan Gunawardena',
                  license: 'SLMC-8829',
                  digitalSignature: '0x7F83D2A955BC71E840F93CD128A98E10129B8C32',
                ),
                clinical: ClinicalData(
                  condition: 'Essential Hypertension (Demo Mode)',
                  conditionCode: 'ICD-10-I10',
                  medication: 'Losartan Potassium 50mg',
                  medicationCode: 'RxNorm-855332',
                  dosage: '1 tablet daily',
                  notes: 'Monitor blood pressure weekly. Limit sodium intake.',
                ),
                translations: TranslationData(
                  conditionSi: 'අධික රුධිර පීඩනය (හෘද හා රුධිර වාහිනී ආශ්‍රිත)',
                  conditionTa: 'அத்தியாவசிய உயர் இரத்த அழுத்தம்',
                  medicationSi: 'රුධිර පීඩනය පාලනය කිරීම සඳහා දිනපතා ලබාගන්නා ඖෂධයකි.',
                  medicationTa: 'இரத்த அழுத்தத்தைக் கட்டுப்படுத்த தினசரி உட்கொள்ளும் மருந்து.',
                  notesSi: 'සෑම සතියකම රුධිර පීඩනය පරීක්ෂා කරන්න. ලුණු භාවිතය සීමා කරන්න.',
                  notesTa: 'ஒவ்வொரு வாரமும் இரத்த அழுத்தத்தை கண்காணிக்கவும். உணவில் உப்பை குறைக்கவும்.',
                ),
              ),
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebasePhrService.instance.getMedicalTimeline(patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snapshot.data?.docs;
                if (snapshot.hasError || docs == null || docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No medical records logged. Verify Firestore permissions or initialize the mock DB.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }

                // Parse only the most recent entry for preview
                final logData = docs.first.data();
                final medicalLog = MedicalLog.fromJson(logData);

                return MedicalTimelineCard(log: medicalLog);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentFallback({
    required String message,
    required bool showInit,
    required String patientId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_rounded, color: Colors.amber[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          if (showInit) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebasePhrService.instance.initializeMockData(patientId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Firestore database populated with sample PHR data.'),
                        backgroundColor: _primaryGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Initialization Error: $e'),
                        backgroundColor: Colors.red[800],
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen.withOpacity(0.08),
                foregroundColor: _primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Initialize Mock Firestore Database',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }

  String _formatAppointmentDate(DateTime dt) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    
    // Day suffix parsing
    String suffix = 'th';
    final digit = dt.day % 10;
    if ((dt.day < 10 || dt.day > 20) && digit >= 1 && digit <= 3) {
      suffix = ['st', 'nd', 'rd'][digit - 1];
    }
    
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');

    return '$dayName, ${dt.day}$suffix $monthName ${dt.year} at $hour:$minuteStr $period';
  }

  Widget _buildAnalyticsSection(String patientId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLINICAL ANALYTICS & SAFETY',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          
          // 1. ADR Tracker Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFFB71C1C).withOpacity(0.4) : const Color(0xFFFFCDD2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Suspected ADR Tracker',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                      color: Colors.red[800],
                      onPressed: () => _showAddAdrDialog(patientId),
                      tooltip: 'Report Suspected Reaction',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The following medications are flagged as high risk for adverse reactions based on home visiting diagnostics:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Fetch list of ADRs from Firestore or Local State (Offline Mode)
                Firebase.apps.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _localAdrs.map((item) {
                          return _buildAdrBulletPoint(
                            drug: item['drugName']!,
                            reaction: item['reaction']!,
                            isDark: isDark,
                            adrId: item['id']!,
                            patientId: patientId,
                          );
                        }).toList(),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebasePhrService.instance.getAdrs(patientId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final docs = snapshot.data?.docs;
                          if (snapshot.hasError || docs == null || docs.isEmpty) {
                            // Fallback to initial local state list
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _localAdrs.map((item) {
                                return _buildAdrBulletPoint(
                                  drug: item['drugName']!,
                                  reaction: item['reaction']!,
                                  isDark: isDark,
                                  adrId: item['id']!,
                                  patientId: patientId,
                                );
                              }).toList(),
                            );
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: docs.map((doc) {
                              final data = doc.data();
                              final adrId = doc.id;
                              final drugName = data['drugName'] ?? '';
                              final reaction = data['reaction'] ?? '';
                              return _buildAdrBulletPoint(
                                drug: drugName,
                                reaction: reaction,
                                isDark: isDark,
                                adrId: adrId,
                                patientId: patientId,
                              );
                            }).toList(),
                          );
                        },
                      ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C0E0E) : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Safety Alert: Inform your prescribing physician about these reactions during your next consult.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 2. Dynamic prescribed medications list to buy (based on diagnoses & timeline visits)
          _buildMedicationsToBuyCard(patientId),
          

        ],
      ),
    );
  }

  Widget _buildAdrBulletPoint({
    required String drug,
    required String reaction,
    required bool isDark,
    String? adrId,
    String? patientId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (adrId != null && patientId != null)
              ? () => _showAddAdrDialog(patientId, adrId: adrId, initialDrug: drug, initialReaction: reaction)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.brightness_1, size: 6, color: Color(0xFFC62828)),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: '$drug: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: reaction,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                if (adrId != null && patientId != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAddAdrDialog(patientId, adrId: adrId, initialDrug: drug, initialReaction: reaction),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (Firebase.apps.isEmpty) {
                        setState(() {
                          _localAdrs.removeWhere((item) => item['id'] == adrId);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reaction for $drug deleted locally.'),
                            backgroundColor: const Color(0xFFC62828),
                          ),
                        );
                        return;
                      }
                      try {
                        await FirebasePhrService.instance.deleteAdr(
                          patientId: patientId,
                          adrId: adrId,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reaction for $drug deleted.'),
                            backgroundColor: const Color(0xFFC62828),
                          ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete reaction: $e')),
                          );
                        }
                      }
                    },
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showAddAdrDialog(String patientId, {String? adrId, String? initialDrug, String? initialReaction}) {
    final drugController = TextEditingController(text: initialDrug);
    final reactionController = TextEditingController(text: initialReaction);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = adrId != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          isEdit ? 'Edit Suspected ADR' : 'Report Suspected ADR',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.red[800],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: drugController,
              decoration: InputDecoration(
                labelText: 'Suspected Medication Name',
                hintText: 'e.g. Amoxicillin',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reactionController,
              decoration: InputDecoration(
                labelText: 'Observed Side Effect / Reaction',
                hintText: 'e.g. Skin rashes, vomiting',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
            onPressed: () async {
              final drug = drugController.text.trim();
              final reaction = reactionController.text.trim();
              if (drug.isNotEmpty && reaction.isNotEmpty) {
                if (Firebase.apps.isEmpty) {
                  setState(() {
                    if (isEdit) {
                      final idx = _localAdrs.indexWhere((item) => item['id'] == adrId);
                      if (idx != -1) {
                        _localAdrs[idx] = {
                          'id': adrId,
                          'drugName': drug,
                          'reaction': reaction,
                        };
                      }
                    } else {
                      final newId = 'adr_${DateTime.now().millisecondsSinceEpoch}';
                      _localAdrs.add({
                        'id': newId,
                        'drugName': drug,
                        'reaction': reaction,
                      });
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'ADR updated locally.' : 'ADR saved locally.'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                  return;
                }
                
                try {
                  if (isEdit) {
                    await FirebasePhrService.instance.updateAdr(
                      patientId: patientId,
                      adrId: adrId,
                      drugName: drug,
                      reaction: reaction,
                    );
                  } else {
                    await FirebasePhrService.instance.addAdr(
                      patientId: patientId,
                      drugName: drug,
                      reaction: reaction,
                    );
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'ADR updated successfully.' : 'ADR reported: $drug successfully saved.'),
                        backgroundColor: Colors.green[800],
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save ADR: $e'),
                        backgroundColor: Colors.red[800],
                      ),
                    );
                  }
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showRequestAppointmentDialog(String patientId) {
    final doctorController = TextEditingController(text: 'Dr. Ruwan Gunawardena');
    final specialtyController = TextEditingController(text: 'Cardiologist');
    final facilityController = TextEditingController(text: 'Hemas Hospital');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7)); // Default 1 week out

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              'Request Doctor Appointment',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Note: Government clinic dates are scheduled and notified directly by your physician/hospital. Use this form to request appointments from private practitioners.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? Colors.amber[200] : Colors.amber[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: doctorController,
                    decoration: InputDecoration(
                      labelText: 'Doctor Name',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: specialtyController,
                    decoration: InputDecoration(
                      labelText: 'Specialty',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: facilityController,
                    decoration: InputDecoration(
                      labelText: 'Private Hospital / Clinic Facility',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Date:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final dt = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (dt != null) {
                            setStateDialog(() {
                              selectedDate = DateTime(
                                dt.year,
                                dt.month,
                                dt.day,
                                selectedDate.hour,
                                selectedDate.minute,
                              );
                            });
                          }
                        },
                        child: Text(_formatClinicDate(selectedDate)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final doctor = doctorController.text.trim();
                  final specialty = specialtyController.text.trim();
                  final facility = facilityController.text.trim();
                  if (doctor.isNotEmpty && specialty.isNotEmpty && facility.isNotEmpty) {
                    try {
                      await FirebasePhrService.instance.requestAppointment(
                        patientId: patientId,
                        doctorName: doctor,
                        specialty: specialty,
                        facilityName: facility,
                        isGovernmentHospital: false,
                        dateTime: selectedDate,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Appointment request sent to $doctor at $facility.'),
                            backgroundColor: _primaryGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red[800],
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatClinicDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildMedicationsToBuyCard(String patientId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePhrService.instance.getMedicalTimeline(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snapshot.data?.docs;
        if (snapshot.hasError || docs == null || docs.isEmpty) {
          return const SizedBox.shrink(); // Hide if no medical timeline entries exist
        }

        // Parse unique medications and dosages from the timeline
        final List<Map<String, String>> medsToBuy = [];
        final Set<String> uniqueMeds = {};

        for (var doc in docs) {
          final data = doc.data();
          final clinical = data['clinical'] as Map<String, dynamic>?;
          if (clinical != null) {
            final rawMed = clinical['medication'] as String? ?? '';
            final rawDosage = clinical['dosage'] as String? ?? '';
            final rawCondition = clinical['condition'] as String? ?? '';

            if (rawMed.isNotEmpty) {
              final decryptedMed = EncryptionService.decrypt(rawMed);
              final decryptedDosage = rawDosage;
              final decryptedCondition = EncryptionService.decrypt(rawCondition);

              final uniqueKey = '${decryptedMed.toLowerCase().trim()}_${decryptedDosage.toLowerCase().trim()}';
              if (!uniqueMeds.contains(uniqueKey)) {
                uniqueMeds.add(uniqueKey);
                medsToBuy.add({
                  'name': decryptedMed,
                  'dosage': decryptedDosage,
                  'condition': decryptedCondition,
                });
              }
            }
          }
        }

        if (medsToBuy.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_rounded, color: _primaryGreen, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Prescribed Medicines to Buy / Refill',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Checklist of medications from your diagnosis & clinical history:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: medsToBuy.length,
                itemBuilder: (context, index) {
                  final med = medsToBuy[index];
                  return _buildMedChecklistItem(
                    med['name']!,
                    med['dosage']!,
                    med['condition']!,
                    isDark,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedChecklistItem(String name, String dosage, String condition, bool isDark) {
    final key = '${name.trim().toLowerCase()}_${dosage.trim().toLowerCase()}';
    final isChecked = _checkedMeds.contains(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isChecked) {
              _checkedMeds.remove(key);
            } else {
              _checkedMeds.add(key);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: isChecked
                    ? _primaryGreen
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isChecked
                            ? (isDark ? Colors.grey[500] : Colors.grey[400])
                            : (isDark ? Colors.white : Colors.black87),
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dosage - for $condition',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isChecked
                            ? (isDark ? Colors.grey[600] : Colors.grey[500])
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
