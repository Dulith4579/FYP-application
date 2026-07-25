import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';
import '../widgets/medical_timeline_card.dart';

/// Screen displaying the complete longitudinal Clinical History for the patient.
///
/// Under live mode, it binds to the real-time Firestore collection stream.
/// Under offline demo mode, it displays 3 pre-defined clinical entries
/// demonstrating trilingual patient summaries and the AI Jargon Explainer.
class PastRecordsScreen extends StatefulWidget {
  const PastRecordsScreen({super.key});

  @override
  State<PastRecordsScreen> createState() => _PastRecordsScreenState();
}

class _PastRecordsScreenState extends State<PastRecordsScreen> {
  final String _selectedPatientId = 'patient_014172';

  // Theme Constants matching Clinical Green styling
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF5F7F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        elevation: 0,
        title: const Text(
          'Clinical History',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Firebase.apps.isEmpty
            ? _buildMockRecordsList()
            : _buildStreamRecordsList(),
      ),
    );
  }

  /// Builds the offline list of 3 pre-defined mock records.
  Widget _buildMockRecordsList() {
    final List<MedicalLog> mockLogs = [
      // Log 1: Essential Hypertension
      MedicalLog(
        logId: 'log_889211',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        doctor: DoctorMetadata(
          name: 'Dr. Ruwan Gunawardena',
          license: 'SLMC-8829',
          digitalSignature: '0x7F83D2A955BC71E840F93CD128A98E10129B8C32',
        ),
        clinical: ClinicalData(
          condition: 'Essential Hypertension',
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
      // Log 2: Type 2 Diabetes Mellitus
      MedicalLog(
        logId: 'log_889212',
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
        doctor: DoctorMetadata(
          name: 'Dr. Ruwan Gunawardena',
          license: 'SLMC-8829',
          digitalSignature: '0x8A92D2C955FF71E840F93CD128A98E10129B9C34',
        ),
        clinical: ClinicalData(
          condition: 'Type 2 Diabetes Mellitus',
          conditionCode: 'ICD-10-E11',
          medication: 'Metformin Hydrochloride 500mg',
          medicationCode: 'RxNorm-311697',
          dosage: '1 tablet twice daily after meals',
          notes: 'Check blood sugar levels twice a week. Exercise regularly.',
        ),
        translations: TranslationData(
          conditionSi: '2 වන කාණ්ඩයේ දියවැඩියාව (පාලනය කළ යුතු)',
          conditionTa: 'வகை 2 நீரிழிவு நோய்',
          medicationSi: 'දියවැඩියාව පාලනය සඳහා ආහාර ගැනීමෙන් පසු ලබාගන්නා ඖෂධයකි.',
          medicationTa: 'நீரிழிவு நோயைக் கட்டுப்படுத்த உணவுக்குப் பின் உட்கொள்ளும் மருந்து.',
          notesSi: 'සතියකට දෙවරක් රුධිරයේ සීනි මට්ටම පරීක්ෂා කරන්න. නිතිපතා ව්‍යායාම කරන්න.',
          notesTa: 'வாரத்திற்கு இரண்டு முறை இரத்த சர்க்கரை அளவை சரிபார்க்கவும். வழக்கமாக உடற்பயிற்சி செய்யவும்.',
        ),
      ),
      // Log 3: Hypercholesterolemia
      MedicalLog(
        logId: 'log_889213',
        timestamp: DateTime.now().subtract(const Duration(days: 30)),
        doctor: DoctorMetadata(
          name: 'Dr. Ruwan Gunawardena',
          license: 'SLMC-8829',
          digitalSignature: '0x9B13C2A955DE71E840F93CD128A98E10129A8D35',
        ),
        clinical: ClinicalData(
          condition: 'Hypercholesterolemia',
          conditionCode: 'SNOMED-CT-394883002',
          medication: 'Atorvastatin 20mg',
          medicationCode: 'RxNorm-Generic',
          dosage: '1 tablet at night',
          notes: 'Avoid oily food. Re-check lipid profile in 3 months.',
        ),
        translations: TranslationData(
          conditionSi: 'අධික කොලෙස්ටරෝල් තත්ත්වය (රුධිරයේ මේද වැඩිවීම)',
          conditionTa: 'உயர் கொழுப்பு',
          medicationSi: 'රුධිරයේ අහිතකර කොලෙස්ටරෝල් මට්ටම අඩු කිරීම සඳහා රාත්‍රී කාලයේ ගන්නා ඖෂධයකි.',
          medicationTa: 'இரத்த கொழுப்பைக் குறைக்க இரவில் உட்கொள்ளும் மருந்து.',
          notesSi: 'තෙල් සහිත ආහාර වලින් වළකින්න. මාස 3කින් ලිපිඩ මට්ටම පරීක්ෂා කරන්න.',
          notesTa: 'எண்ணெய் உணவுகளை தவிர்க்கவும். 3 மாதங்களில் கொழுப்பு சுயவிவரத்தை மீண்டும் சரிபார்க்கவும்.',
        ),
      ),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: mockLogs.length,
      itemBuilder: (context, index) {
        return MedicalTimelineCard(log: mockLogs[index]);
      },
    );
  }

  /// Builds the real-time list driven by the Firestore stream.
  Widget _buildStreamRecordsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePhrService.instance.getMedicalTimeline(_selectedPatientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs;
        if (snapshot.hasError || docs == null || docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Past Records Found',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Initialize the database from the dashboard or complete a doctor consultation to log new entries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final logData = docs[index].data();
            final medicalLog = MedicalLog.fromJson(logData);
            return MedicalTimelineCard(log: medicalLog);
          },
        );
      },
    );
  }
}
