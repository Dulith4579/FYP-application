import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';
import '../widgets/patient_auth_bottom_sheet.dart';
import '../widgets/medical_timeline_card.dart';
import 'doctor_session_screen.dart';
import 'clinical_ai_analyzer_screen.dart';

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

  // Clinical Green Palette
  static const Color _primaryGreen = Color(0xFF1B5E20);   // Deep Forest Green
  static const Color _accentGreen = Color(0xFF4CAF50);    // Mint Green
  static const Color _bgColor = Color(0xFFF5F7F5);        // Clean Light Slate/Grey
  static const Color _cardBorderColor = Color(0xFFC8E6C9);

  /// Shows the generated QR connection code modal, allowing the patient to
  /// simulate scanning the doctor's reader and granting authorization.
  void _showQRGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Text(
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
                color: Colors.grey[850],
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'Session ID: session_9941A',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
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
                  patientId: _selectedPatientId,
                );
              },
              icon: const Icon(Icons.sensors, color: Colors.white),
              label: const Text('Simulate Scan (Open Auth Sheet)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
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
          const SnackBar(
            content: Text('Firestore database populated with sample PHR data.'),
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        elevation: 0,
        title: const Text(
          'My PHR Dashboard',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DoctorSessionScreen()),
              );
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
              // Top Section: Interactive QR Generation Container
              _buildQRSection(),

              // Middle Section: Real-time Next Appointment Listener Card
              _buildAppointmentSection(),

              // AI Translator Card Section
              _buildAiAnalyzerCard(),

              // Bottom Section: Medical Timeline Feed Previewer
              _buildTimelineSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
          
          // Prominent interactive QR button
          InkWell(
            onTap: _showQRGeneratorDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _primaryGreen,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Generate Session QR',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING CONSULTATION',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          
          if (Firebase.apps.isEmpty)
            // Render the mock card directly for demo mode!
            _buildAppointmentCard(
              doctorName: 'Dr. Ruwan Gunawardena',
              specialty: 'Cardiologist (Demo Mode)',
              facility: 'Hemas Hospital',
              dateStr: 'Sunday, 28th June 2026 at 10:30 AM',
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebasePhrService.instance.getNextAppointment(_selectedPatientId),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentGreen, width: 1.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: _primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$dateStr\n@ $facility',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalyzerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOCAL AI ASSISTANT',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorderColor, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClinicalAiAnalyzer()),
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
                        child: const Icon(
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
                            const Text(
                              'Translate & Summarize Notes',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Convert messy clinical terms and descriptions into plain English, Sinhala, and Tamil.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey[400],
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

  Widget _buildTimelineSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 32),
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
                color: Colors.grey[700],
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
              stream: FirebasePhrService.instance.getMedicalTimeline(_selectedPatientId),
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
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No medical records logged. Verify Firestore permissions or initialize the mock DB.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', color: Colors.black54),
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

  Widget _buildAppointmentFallback({required String message, required bool showInit}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
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
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          if (showInit) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeDatabaseData,
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
}
