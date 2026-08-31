import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'encryption_service.dart';
import 'translation_service.dart';

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
  Future<void> resetSession(String sessionId, String doctorUid, String doctorName, String license) async {
    try {
      await _db.collection('sessions').doc(sessionId).set({
        'status': 'pending',
        'patientId': '',
        'accessLevel': '',
        'doctorUid': doctorUid,
        'doctorName': doctorName,
        'license': license,
        'expiresAt': DateTime.now().add(const Duration(minutes: 15)),
      });
    } catch (e) {
      throw Exception('Failed to reset session: $e');
    }
  }

  // Memory fallback for doctor keys
  static final Map<String, String> _doctorKeyMemoryStorage = {};

  /// Initializes doctor keys in local secure storage and Firestore.
  Future<void> initializeDoctorKeys(String doctorId) async {
    const secureStorage = FlutterSecureStorage();
    String? privKeyStr;
    String? pubKeyStr;
    
    try {
      privKeyStr = await secureStorage.read(key: 'rsa_priv_$doctorId').timeout(const Duration(seconds: 1));
      pubKeyStr = await secureStorage.read(key: 'rsa_pub_$doctorId').timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Doctor secure storage read failed, using memory fallback: $e');
      privKeyStr = _doctorKeyMemoryStorage['rsa_priv_$doctorId'];
      pubKeyStr = _doctorKeyMemoryStorage['rsa_pub_$doctorId'];
    }
    
    if (privKeyStr == null || pubKeyStr == null) {
      // Offload CPU-intensive RSA keypair generation off the main UI thread
      final pair = await compute((_) => EncryptionService.generateRSAKeyPair(), null);
      privKeyStr = EncryptionService.serializePrivateKey(pair.privateKey);
      pubKeyStr = EncryptionService.serializePublicKey(pair.publicKey);
      
      try {
        await secureStorage.write(key: 'rsa_priv_$doctorId', value: privKeyStr);
        await secureStorage.write(key: 'rsa_pub_$doctorId', value: pubKeyStr);
      } catch (e) {
        debugPrint('Doctor secure storage write failed, using memory fallback: $e');
        _doctorKeyMemoryStorage['rsa_priv_$doctorId'] = privKeyStr;
        _doctorKeyMemoryStorage['rsa_pub_$doctorId'] = pubKeyStr;
      }
    }
    
    // Upload public key to Firestore asynchronously
    if (Firebase.apps.isNotEmpty) {
      unawaited(_db.collection('users').doc(doctorId).set({
        'publicKey': pubKeyStr,
      }, SetOptions(merge: true)));
    }
  }

  /// Decrypts the patient's AES session key using the doctor's private RSA key.
  Future<String> decryptSessionKey(String doctorId, String encryptedAesKeyBase64) async {
    const secureStorage = FlutterSecureStorage();
    String? privKeyStr;
    try {
      privKeyStr = await secureStorage.read(key: 'rsa_priv_$doctorId');
    } catch (e) {
      debugPrint('Decrypt secure storage read failed, using memory fallback: $e');
    }
    
    privKeyStr ??= _doctorKeyMemoryStorage['rsa_priv_$doctorId'];
    
    if (privKeyStr == null) {
      throw Exception('Doctor private RSA key not initialized.');
    }
    
    final privKey = EncryptionService.deserializePrivateKey(privKeyStr);
    final encryptedBytes = base64.decode(encryptedAesKeyBase64);
    
    final decrypter = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privKey));
    
    final decryptedBytes = decrypter.process(Uint8List.fromList(encryptedBytes));
    return utf8.decode(decryptedBytes);
  }

  // --- FIRESTORE BLOCKCHAIN LEDGER HASH-CHAINING STATE ---
  static String _lastBlockHash = '0000000000000000000000000000000000000000000000000000000000000000';
  static int _blockchainHeight = 0;

  /// Cryptographically links records into a sequential SHA-256 hash-chain block
  static Map<String, dynamic> _generateBlockchainBlock(String dataPayloadStr) {
    _blockchainHeight++;
    final dataHash = crypto.sha256.convert(utf8.encode(dataPayloadStr)).toString();
    final previousHash = _lastBlockHash;
    final blockHash = crypto.sha256.convert(utf8.encode('$_blockchainHeight|$previousHash|$dataHash')).toString();
    _lastBlockHash = blockHash;

    return {
      'blockIndex': _blockchainHeight,
      'previousHash': previousHash,
      'dataHash': dataHash,
      'blockHash': blockHash,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Appends an immutable audit log receipt to the audit_logs collection with Blockchain Block headers.
  Future<void> logAudit({
    required String actorId,
    required String actorRole,
    required String action,
    required String details,
    required String patientId,
    String? sessionId,
  }) async {
    final blockHeader = _generateBlockchainBlock('$actorId|$actorRole|$action|$details|$patientId');
    if (Firebase.apps.isEmpty) return;
    try {
      await _db.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'actorId': actorId,
        'actorRole': actorRole,
        'action': action,
        'details': details,
        'patientId': patientId,
        'sessionId': sessionId ?? '',
        'blockchain': blockHeader,
      });
    } catch (e) {
      debugPrint("Failed to log audit receipt: $e");
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
    required String patientName,
    required String condition,
    required String medication,
    required String dosage,
    required String notes,
    required String doctorName,
    required String license,
    required String doctorUid,
  }) async {
    try {
      final timelineCollection = _db
          .collection('users')
          .doc(patientId)
          .collection('medical_timeline');

      final logId = 'log_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // --- LIVE GOOGLE TRANSLATION SERVICES ---
      String conditionSi = condition;
      String conditionTa = condition;
      String medicationSi = medication;
      String medicationTa = medication;
      String notesSi = notes;
      String notesTa = notes;

      try {
        final List<String> translationResults = await Future.wait([
          TranslationService.translate(condition, 'si'),
          TranslationService.translate(condition, 'ta'),
          TranslationService.translate(medication, 'si'),
          TranslationService.translate(medication, 'ta'),
          TranslationService.translate(notes, 'si'),
          TranslationService.translate(notes, 'ta'),
        ]);

        conditionSi = translationResults[0];
        conditionTa = translationResults[1];
        medicationSi = translationResults[2];
        medicationTa = translationResults[3];
        notesSi = translationResults[4];
        notesTa = translationResults[5];
      } catch (e) {
        // Fallback to input string if translation api fails or key is missing
        debugPrint("Real-time Translation failed, using fallback: $e");
      }

      // Derive key for patient so both patient and doctor can decrypt seamlessly
      final String patientKeyBase64 = EncryptionService.deriveKey('passcode_fyp_123', patientId);
      final patientKey = enc.Key.fromBase64(patientKeyBase64);

      final String encryptedCondition = EncryptionService.encrypt(condition, key: patientKey);
      final String encryptedMedication = EncryptionService.encrypt(medication, key: patientKey);
      final String encryptedNotes = EncryptionService.encrypt(notes, key: patientKey);

      // Retrieve doctor keys to sign the medical record
      const secureStorage = FlutterSecureStorage();
      final privKeyStr = await secureStorage.read(key: 'rsa_priv_$doctorUid');
      final pubKeyStr = await secureStorage.read(key: 'rsa_pub_$doctorUid');
      
      String signatureBlock = 'Unsigned';
      if (privKeyStr != null) {
        final privKey = EncryptionService.deserializePrivateKey(privKeyStr);
        final plainTextToSign = '$condition|$medication|$dosage|$notes|$doctorName|$license';
        signatureBlock = EncryptionService.rsaSign(plainTextToSign, privKey);
      }

      final blockHeader = _generateBlockchainBlock('$logId|$patientId|$doctorUid|$encryptedCondition|$encryptedMedication');

      await timelineCollection.doc(logId).set({
        'logId': logId,
        'patientName': patientName,
        'timestamp': FieldValue.serverTimestamp(),
        'doctor': {
          'name': doctorName,
          'license': license,
          'digitalSignature': signatureBlock,
          'publicKey': pubKeyStr ?? '',
        },
        'clinical': {
          'condition': encryptedCondition,
          'conditionCode': condition.toLowerCase().contains('diabetes') ? 'ICD-10-E11' : (condition.toLowerCase().contains('hypertension') ? 'ICD-10-I10' : 'SNOMED-CT-394883002'),
          'medication': encryptedMedication,
          'medicationCode': medication.toLowerCase().contains('metformin') ? 'RxNorm-311697' : (medication.toLowerCase().contains('losartan') ? 'RxNorm-855332' : 'RxNorm-Generic'),
          'dosage': dosage,
          'notes': encryptedNotes,
        },
        'translations': {
          'condition_si': conditionSi,
          'condition_ta': conditionTa,
          'medication_si': medicationSi,
          'medication_ta': medicationTa,
          'notes_si': notesSi.isNotEmpty ? 'විශේෂ උපදෙස්: $notesSi' : '',
          'notes_ta': notesTa.isNotEmpty ? 'குறிப்பு: $notesTa' : '',
        },
        'blockchain': blockHeader,
      });

      // Write immutable audit log for the creation event
      await logAudit(
        actorId: doctorUid,
        actorRole: 'doctor',
        action: 'CREATED_RECORD',
        details: 'Created and cryptographically signed timeline record $logId for patient $patientId',
        patientId: patientId,
      );
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

    // Mock ADRs
    final adrCollection = _db.collection('users').doc(patientId).collection('adrs');
    batch.set(adrCollection.doc('adr_penicillin'), {
      'drugName': 'Penicillin',
      'reaction': 'Allergic skin rashes (Urticaria)',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(adrCollection.doc('adr_metformin'), {
      'drugName': 'Metformin',
      'reaction': 'Severe gastrointestinal cramps',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(adrCollection.doc('adr_aspirin'), {
      'drugName': 'Aspirin',
      'reaction': 'Gastric mucosal irritation & acidity',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Saves a new suspected Adverse Drug Reaction (ADR) under the patient's record.
  Future<void> addAdr({
    required String patientId,
    required String drugName,
    required String reaction,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(patientId)
          .collection('adrs')
          .add({
        'drugName': drugName,
        'reaction': reaction,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save ADR: $e');
    }
  }

  /// Updates an existing suspected Adverse Drug Reaction (ADR) under the patient's record.
  Future<void> updateAdr({
    required String patientId,
    required String adrId,
    required String drugName,
    required String reaction,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(patientId)
          .collection('adrs')
          .doc(adrId)
          .update({
        'drugName': drugName,
        'reaction': reaction,
      });
    } catch (e) {
      throw Exception('Failed to update ADR: $e');
    }
  }

  /// Deletes a suspected Adverse Drug Reaction (ADR) under the patient's record.
  Future<void> deleteAdr({
    required String patientId,
    required String adrId,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(patientId)
          .collection('adrs')
          .doc(adrId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete ADR: $e');
    }
  }

  /// Retrieves a real-time stream of the patient's Adverse Drug Reactions (ADRs).
  Stream<QuerySnapshot<Map<String, dynamic>>> getAdrs(String patientId) {
    return _db
        .collection('users')
        .doc(patientId)
        .collection('adrs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Submits an appointment request to the Firestore database.
  Future<void> requestAppointment({
    required String patientId,
    required String doctorName,
    required String specialty,
    required String facilityName,
    required bool isGovernmentHospital,
    required DateTime dateTime,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(patientId)
          .collection('appointments')
          .doc('next')
          .set({
        'doctorName': doctorName,
        'specialty': specialty,
        'facilityName': facilityName,
        'isGovernmentHospital': isGovernmentHospital,
        'dateTime': Timestamp.fromDate(dateTime),
        'clinicRoom': isGovernmentHospital ? 'Clinic Room 12' : 'Consultation Suite B',
        'status': 'confirmed',
      });
    } catch (e) {
      throw Exception('Failed to request appointment: $e');
    }
  }
}
