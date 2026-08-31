import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

/// Role-aware user profile model.
class AppUser {
  final String uid;
  final String email;
  final String role; // 'patient' or 'doctor'
  final String displayName;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
  });
}

/// Active selected patient context model.
class ActivePatientProfile {
  final String id;
  final String name;
  final bool isDependent;

  ActivePatientProfile({
    required this.id,
    required this.name,
    required this.isDependent,
  });
}

/// Singleton Authentication Service managing credentials, role-mapping,
/// and graceful fallback capabilities for demo integrity.
class AuthService {
  AuthService._internal() {
    // Listen to Firebase Auth state changes and link to the app stream
    _fbAuth.authStateChanges().listen((fb.User? fbUser) async {
      if (fbUser == null) {
        if (_mockUser == null) {
          _userController.add(null);
          activePatientNotifier.value = null;
        }
      } else {
        // Fetch role from Firestore user document
        final role = await _getUserRoleFromFirestore(fbUser.uid);
        final displayName = fbUser.displayName ?? (role == 'doctor' ? 'Practitioner' : 'Patient');
        final appUser = AppUser(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          role: role,
          displayName: displayName,
        );
        if (role == 'patient') {
          await updateActivePatient(appUser.uid, displayName, false);
        }
        _userController.add(appUser);
      }
    });
  }

  static final AuthService instance = AuthService._internal();

  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream Controller broadcasting role-aware AppUser sessions
  final StreamController<AppUser?> _userController = StreamController<AppUser?>.broadcast();

  // Local state properties for mock backup login sessions
  AppUser? _mockUser;

  // Active selected patient context (can be the main user or a dependent)
  final ValueNotifier<ActivePatientProfile?> activePatientNotifier = ValueNotifier<ActivePatientProfile?>(null);

  // Memory fallback for key storage to ensure web/demo runs flawlessly
  static final Map<String, String> _memoryStorage = {};

  Future<void> updateActivePatient(String id, String name, bool isDependent) async {
    await _loadAndSetActiveKey(id);
    activePatientNotifier.value = ActivePatientProfile(
      id: id,
      name: name,
      isDependent: isDependent,
    );
  }

  Future<void> _loadAndSetActiveKey(String id) async {
    try {
      const secureStorage = FlutterSecureStorage();
      String? derivedKey;
      try {
        derivedKey = await secureStorage.read(key: 'aes_key_$id');
      } catch (e) {
        debugPrint('Secure storage read failed, using memory fallback: $e');
        derivedKey = _memoryStorage['aes_key_$id'];
      }

      if (derivedKey == null || derivedKey.isEmpty) {
        derivedKey = EncryptionService.deriveKey('passcode_fyp_123', id);
        try {
          await secureStorage.write(key: 'aes_key_$id', value: derivedKey);
        } catch (e) {
          debugPrint('Secure storage write failed, using memory fallback: $e');
          _memoryStorage['aes_key_$id'] = derivedKey;
        }
      }
      EncryptionService.setActiveKey(derivedKey);
    } catch (_) {
      EncryptionService.resetKeyToDefault();
    }
  }

  /// Exposes a stream of role-aware user sessions.
  Stream<AppUser?> get authStateChanges => _userController.stream;

  /// Gets the currently authenticated user (Firebase or Mock).
  AppUser? get currentUser {
    if (_mockUser != null) return _mockUser;
    final fbUser = _fbAuth.currentUser;
    if (fbUser != null) {
      // Return a temporary patient role, stream will update asynchronously
      return AppUser(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        role: fbUser.email != null && fbUser.email!.contains('doctor') ? 'doctor' : 'patient',
        displayName: fbUser.displayName ?? 'User',
      );
    }
    return null;
  }

  /// Sign in using Firebase Authentication with dynamic role mapping.
  /// Falls back to a mock user session for demonstrations if the Firebase Auth provider is disabled.
  Future<AppUser> signIn(String email, String password, String selectedRole) async {
    final sanitizedEmail = email.trim();
    final sanitizedPassword = password.trim();

    // Check for demo profiles first to ensure instant mock presentation stability
    if (sanitizedPassword == 'password123' && 
       (sanitizedEmail == 'patient@fyp.com' || sanitizedEmail == 'doctor@fyp.com')) {
      
      final mock = _getMockUserProfile(sanitizedEmail);
      if (mock.role != selectedRole) {
        throw Exception('Access Denied: Account role mismatch.');
      }

      // Fire Firebase Auth sign in asynchronously in background without blocking login navigation
      unawaited(_fbAuth
          .signInWithEmailAndPassword(email: sanitizedEmail, password: sanitizedPassword)
          .timeout(const Duration(seconds: 2))
          .then<void>((_) => null)
          .catchError((_) {}));

      _mockUser = mock;
      if (mock.role == 'patient') {
        unawaited(updateActivePatient(mock.uid, mock.displayName, false));
      }
      _userController.add(_mockUser);
      return _mockUser!;
    }

    try {
      // Attempt standard Firebase Auth sign in with a fast 4-second timeout
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      ).timeout(const Duration(seconds: 4));

      final fbUser = credential.user;
      if (fbUser == null) throw Exception('User not found.');

      // Check role mapping with fast fallback
      final role = await _getUserRoleFromFirestore(fbUser.uid);
      if (role != selectedRole) {
        await _fbAuth.signOut();
        throw Exception('Access Denied: Account role mismatch.');
      }

      final appUser = AppUser(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        role: role,
        displayName: fbUser.displayName ?? (role == 'doctor' ? 'Practitioner' : 'Patient'),
      );

      _mockUser = null;
      _userController.add(appUser);
      return appUser;
    } on TimeoutException {
      // Fast fallback to mock demo user if network connection hangs
      final mock = _getMockUserProfile(sanitizedEmail);
      if (mock.role == selectedRole) {
        _mockUser = mock;
        _userController.add(_mockUser);
        return _mockUser!;
      }
      throw Exception('Connection timed out. Please check network connection.');
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return await register(sanitizedEmail, sanitizedPassword, selectedRole);
      }
      throw Exception('Invalid credentials or account mismatch.');
    } catch (e) {
      if (e.toString().contains('Access Denied')) {
        rethrow;
      }
      throw Exception('Invalid credentials or account mismatch.');
    }
  }

  /// Registers a new user in Firebase Auth and populates their role in Firestore.
  Future<AppUser> register(String email, String password, String role) async {
    try {
      final credential = await _fbAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 5));

      final fbUser = credential.user;
      if (fbUser == null) throw Exception('Registration failed.');

      // Save role mapping in Firestore users collection
      unawaited(_db.collection('users').doc(fbUser.uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));

      final appUser = AppUser(
        uid: fbUser.uid,
        email: email,
        role: role,
        displayName: role == 'doctor' ? 'Practitioner' : 'Patient',
      );

      _mockUser = null;
      if (role == 'patient') {
        unawaited(updateActivePatient(appUser.uid, appUser.displayName, false));
      }
      _userController.add(appUser);
      return appUser;
    } catch (e) {
      throw Exception('Failed to register account: $e');
    }
  }

  /// Logs the user out of Firebase and resets any mock session state.
  Future<void> signOut() async {
    try {
      await _fbAuth.signOut().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _mockUser = null;
    activePatientNotifier.value = null;
    EncryptionService.resetKeyToDefault();
    _userController.add(null);
  }

  // Helper method fetching role mappings from Cloud Firestore users collection
  Future<String> _getUserRoleFromFirestore(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 2));
      if (doc.exists) {
        return doc.data()?['role'] as String? ?? 'patient';
      }
    } catch (_) {}
    // Default fallback based on email context if DB access fails
    final email = _fbAuth.currentUser?.email;
    if (email != null && email.contains('doctor')) {
      return 'doctor';
    }
    return 'patient';
  }

  // Pre-configured mock profile details matching existing mock data identifiers
  AppUser _getMockUserProfile(String email) {
    if (email == 'doctor@fyp.com') {
      return AppUser(
        uid: 'doctor_8829',
        email: 'doctor@fyp.com',
        role: 'doctor',
        displayName: 'Dr. Ruwan Gunawardena',
      );
    } else {
      return AppUser(
        uid: 'patient_014172',
        email: 'patient@fyp.com',
        role: 'patient',
        displayName: 'Dulith Chandira',
      );
    }
  }
}
