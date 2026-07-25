import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'screens/main_navigation_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Commented out to force 100% offline local demo mode
  /*
  try {
    // Initializes Firebase using native configurations (google-services.json / GoogleService-Info.plist)
    await Firebase.initializeApp();
    debugPrint('Firebase successfully initialized natively.');
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
    debugPrint('Note: To connect to your live database, configure your Firebase credentials (flutterfire configure).');
  }
  */
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Personal Health Record',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1B5E20),
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF4CAF50),
        ),
      ),
      home: const MainNavigationWrapper(),
    );
  }
}
