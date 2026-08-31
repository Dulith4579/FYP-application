import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/main_navigation_wrapper.dart';
import 'screens/login_screen.dart';
import 'screens/doctor_session_screen.dart';
import 'services/auth_service.dart';

import 'services/local_cache_service.dart';

// global notifier for theme changes
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.init();
  
  try {
    if (kIsWeb) {
      // Initializes Firebase for Web using values from your Firebase web config document
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBMTPN-pEy2q-TFo6gGo0EFHwEVr-oWyT8",
          authDomain: "fyp-project-a3137.firebaseapp.com",
          projectId: "fyp-project-a3137",
          storageBucket: "fyp-project-a3137.firebasestorage.app",
          messagingSenderId: "640923854343",
          appId: "1:640923854343:web:8809187490d5e37b412ca2",
          measurementId: "G-78G87VMLJD",
        ),
      );
      debugPrint('Firebase successfully initialized for Web.');
    } else {
      // Initializes Firebase using native configurations (google-services.json) on mobile
      await Firebase.initializeApp();
      debugPrint('Firebase successfully initialized natively.');
    }
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'AI Personal Health Record',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF1B5E20),
            scaffoldBackgroundColor: const Color(0xFFF5F7F5),
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B5E20),
              primary: const Color(0xFF1B5E20),
              secondary: const Color(0xFF4CAF50),
              surface: Colors.white,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF81C784),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B5E20),
              primary: const Color(0xFF81C784),
              secondary: const Color(0xFF4CAF50),
              surface: const Color(0xFF1E1E1E),
              brightness: Brightness.dark,
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        
        if (user.role == 'doctor') {
          return DoctorSessionScreen(
            doctorName: user.displayName,
          );
        }
        
        return const MainNavigationWrapper();
      },
    );
  }
}
