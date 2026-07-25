import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

/// Service class orchestrating database interactions with Firebase Firestore
/// for the AI-Based Personal Health Record (PHR) System.
/// 
/// Real-Time Stateless Listeners Design Pattern:
/// This service leverages Firestore's `snapshots()` streams. When UI components
/// bind to these streams using [StreamBuilder], they establish a persistent web-socket
/// connection to Firestore. Any database modifications immediately force a state rebuild 
/// on the client-side without needing manual polling or state pull requests, keeping data 
/// synchronized across both patients and practitioners.
class FirebasePhrService {
  // Singleton pattern for application-wide service availability
  FirebasePhrService._internal();
  static final FirebasePhrService instance = FirebasePhrService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retrieves a real-time stream of the patient's medical timeline entries.
  /// 
  /// Path: `users/{patientId}/medical_timeline`
  /// Sorted chronologically (newest entries first).
  Stream<QuerySnapshot<Map<String, dynamic>>> getMedicalTimeline(String patientId) {
    return _db
        .collection('users')
        .doc(patientId)
        .collection('medical_timeline')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Retrieves a real-time stream of the patient's next scheduled appointment.
  /// 
  /// Path: `users/{patientId}/appointments/next`
  /// This single-document subscription minimizes network overhead by listening only
  /// to active, upcoming clinical sessions.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getNextAppointment(String patientId) {
    return _db
        .collection('users')
        .doc(patientId)
        .collection('appointments')
        .doc('next')
        .snapshots();
  }

  /// Retrieves a real-time stream of the registered dependents for a user profile.
  /// 
  /// Path: `users/{mainUserId}/dependents`
  Stream<QuerySnapshot<Map<String, dynamic>>> getDependents(String mainUserId) {
    return _db
        .collection('users')
        .doc(mainUserId)
        .collection('dependents')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Adds a new linked family dependent or ward profile.
  /// 
  /// Path: `users/{mainUserId}/dependents`
  /// 
  /// Useful for pediatric records or geriatric care monitoring, allowing caregivers 
  /// to switch dashboards and consent to data requests on behalf of dependents.
  Future<void> addDependent({
    required String mainUserId,
    required String name,
    required String relationship,
    required String age,
  }) async {
    try {
      final dependentsCollection = _db
          .collection('users')
          .doc(mainUserId)
          .collection('dependents');

      await dependentsCollection.add({
        'name': name,
        'relationship': relationship,
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Re-throw to allow UI forms to catch errors and display feedback to users
      throw Exception('Failed to add family dependent profile: $e');
    }
  }

  /// Retrieves a real-time stream of the connection/authorization session document.
  /// 
  /// Path: `sessions/{sessionId}`
  Stream<DocumentSnapshot<Map<String, dynamic>>> getSessionStream(String sessionId) {
    return _db.collection('sessions').doc(sessionId).snapshots();
  }

  /// Sets or resets a session document back to standard 'pending' status.
  /// 
  /// Path: `sessions/{sessionId}`
  Future<void> resetSession(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).set({
        'status': 'pending',
        'patientId': '',
        'accessLevel': '',
        'expiresAt': DateTime.now().add(const Duration(minutes: 15)),
      });
    } catch (e) {
      throw Exception('Failed to reset session: $e');
    }
  }

  /// Writes a new verified clinician entry directly into a patient's timeline.
  /// 
  /// Path: `users/{patientId}/medical_timeline`
  /// 
  /// Automatically runs mock trilingual translations mimicking your AI pipeline
  /// so translations instantly appear on the patient dashboard UI when written.
  Future<void> submitDiagnosisLog({
    required String patientId,
    required String condition,
    required String medication,
    required String dosage,
    required String notes,
    required String doctorName,
    required String license,
  }) async {
    try {
      final timelineCollection = _db
          .collection('users')
          .doc(patientId)
          .collection('medical_timeline');

      final logId = 'log_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // --- MOCK AI TRANSLATION RULE MAPPING FOR THE DEMO ---
      String conditionSi = 'AI පරිවර්තනය ක්‍රියාත්මක වෙමින් පවතී...';
      String conditionTa = 'AI மொழிபெயர்ப்பு நிலுவையில் உள்ளது...';
      String medicationSi = 'ඖෂධ උපදෙස් AI පරිවර්තනය ක්‍රියාත්මක වෙමින් පවතී...';
      String medicationTa = 'மருந்து வழிமுறைகள் AI மொழிபெயர்ப்பு நிலுவையில் உள்ளது...';

      final conditionLower = condition.toLowerCase();
      final medicationLower = medication.toLowerCase();

      if (conditionLower.contains('diabetes') || conditionLower.contains('sugar')) {
        conditionSi = '2 වන කාණ්ඩයේ දියවැඩියාව (පාලනය කළ යුතු)';
        conditionTa = 'வகை 2 நீரிழிவு நோய்';
      } else if (conditionLower.contains('hypertension') || conditionLower.contains('pressure')) {
        conditionSi = 'අධික රුධිර පීඩනය (හෘද හා රුධිර වාහිනී ආශ්‍රිත)';
        conditionTa = 'அத்தியாவசிய உயர் இரத்த அழுத்தம்';
      } else if (conditionLower.contains('cholesterol') || conditionLower.contains('lipids')) {
        conditionSi = 'අධික කොලෙස්ටරෝල් තත්ත්වය (රුධිරයේ මේදය වැඩිවීම)';
        conditionTa = 'உயர் கொழுப்பு';
      }

      if (medicationLower.contains('metformin')) {
        medicationSi = 'දියවැඩියාව පාලනය සඳහා ආහාර ගැනීමෙන් පසු ලබාගන්නා ඖෂධයකි.';
        medicationTa = 'நீரிழிவு நோயைக் கட்டுப்படுத்த உணவுக்குப் பின் உட்கொள்ளும் மருந்து.';
      } else if (medicationLower.contains('losartan')) {
        medicationSi = 'රුධිර පීඩනය පාලනය කිරීම සඳහා දිනපතා ලබාගන්නා ඖෂධයකි.';
        medicationTa = 'இரத்த அழுத்தத்தைக் கட்டுப்படுத்த தினசரி உட்கொள்ளும் மருந்து.';
      } else if (medicationLower.contains('atorvastatin')) {
        medicationSi = 'රුධිරයේ අහිතකර කොලෙස්ටරෝල් මට්ටම අඩු කිරීම සඳහා රාත්‍රී කාලයේ ගන්නා ඖෂධයකි.';
        medicationTa = 'இரத்த கொழுப்பைக் குறைக்க இரவில் உட்கொள்ளும் மருந்து.';
      }

      final String encryptedCondition = EncryptionService.encrypt(condition);
      final String encryptedMedication = EncryptionService.encrypt(medication);
      final String encryptedNotes = EncryptionService.encrypt(notes);

      await timelineCollection.doc(logId).set({
        'logId': logId,
        'timestamp': FieldValue.serverTimestamp(),
        'doctor': {
          'name': doctorName,
          'license': license,
          'digitalSignature': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}8A4D0C2F',
        },
        'clinical': {
          'condition': encryptedCondition,
          'conditionCode': conditionLower.contains('diabetes') ? 'ICD-10-E11' : (conditionLower.contains('hypertension') ? 'ICD-10-I10' : 'SNOMED-CT-394883002'),
          'medication': encryptedMedication,
          'medicationCode': medicationLower.contains('metformin') ? 'RxNorm-311697' : (medicationLower.contains('losartan') ? 'RxNorm-855332' : 'RxNorm-Generic'),
          'dosage': dosage,
          'notes': encryptedNotes,
        },
        'translations': {
          'condition_si': conditionSi,
          'condition_ta': conditionTa,
          'medication_si': medicationSi,
          'medication_ta': medicationTa,
          'notes_si': notes.isNotEmpty ? 'විශේෂ උපදෙස්: $notes' : '',
          'notes_ta': notes.isNotEmpty ? 'குறிப்பு: $notes' : '',
        }
      });
    } catch (e) {
      throw Exception('Failed to submit clinical timeline log: $e');
    }
  }

  /// Helper method to initialize a mock database schema on Firestore for testing.
  /// Useful for local emulators or initial setup steps.
  Future<void> initializeMockData(String patientId) async {
    final batch = _db.batch();

    // Mock Next Appointment Document
    final nextAppointmentRef = _db
        .collection('users')
        .doc(patientId)
        .collection('appointments')
        .doc('next');
    
    batch.set(nextAppointmentRef, {
      'doctorName': 'Dr. Ruwan Gunawardena',
      'license': 'SLMC-8829',
      'specialty': 'Cardiologist',
      'dateTime': Timestamp.fromDate(DateTime(2026, 6, 28, 10, 30)),
      'facilityName': 'Hemas Hospital',
      'clinicRoom': 'Room 104',
      'status': 'confirmed'
    });

    // Mock Medical Timeline Log Document
    final timelineRef = _db
        .collection('users')
        .doc(patientId)
        .collection('medical_timeline')
        .doc('log_889211');

    batch.set(timelineRef, {
      'logId': 'log_889211',
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
      'doctor': {
        'name': 'Dr. Ruwan Gunawardena',
        'license': 'SLMC-8829',
        'digitalSignature': '0x7F83D2A955BC71E840F93CD128A98E10129B8C32'
      },
      'clinical': {
        'condition': 'Essential Hypertension',
        'conditionCode': 'ICD-10-I10',
        'medication': 'Losartan Potassium 50mg',
        'medicationCode': 'RxNorm-855332',
        'dosage': '1 tablet daily',
        'notes': 'Monitor blood pressure weekly. Limit sodium intake.'
      },
      'translations': {
        'condition_si': 'අධික රුධිර පීඩනය (හෘද හා රුධිර වාහිනී ආශ්‍රිත)',
        'condition_ta': 'அத்தியாவசிய உயர் இரத்த அழுத்தம்',
        'medication_si': 'රුධිර පීඩනය පාලනය කිරීම සඳහා දිනපතා ලබාගන්නා ඖෂධයකි.',
        'medication_ta': 'இரத்த அழுத்தத்தைக் கட்டுப்படுத்த தினசரி உட்கொள்ளும் மருந்து.',
        'notes_si': 'සෑම සතියකම රුධිර පීඩනය පරීක්ෂා කරන්න. ලුණු භාවිතය සීමා කරන්න.',
        'notes_ta': 'ஒவ்வொரு வாரமும் இரத்த அழுத்தத்தை கண்காணிக்கவும். உணவில் உப்பை குறைக்கவும்.'
      }
    });

    // Mock Dependents
    final dependent1Ref = _db
        .collection('users')
        .doc(patientId)
        .collection('dependents')
        .doc('dep_mother');

    batch.set(dependent1Ref, {
      'name': 'Nirmala Gunawardena',
      'relationship': 'Mother',
      'age': '64',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
