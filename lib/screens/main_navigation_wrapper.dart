import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'patient_dashboard_screen.dart';
import 'document_upload_screen.dart';
import 'family_management_screen.dart';
import 'past_records_screen.dart';

/// App shell managing primary layout navigations for the AI-Based PHR.
/// 
/// Uses a Material 3 bottom [NavigationBar] to bridge major screen contexts
/// (Home, Document Upload, Family Dependents, and Doctor Session Console)
/// into a quick-access, stateful layout wrapper.
class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  // Colors mapping the Clinical Green theme
  static const Color _primaryGreen = Color(0xFF1B5E20);   // Deep Forest Green
  static const Color _accentGreen = Color(0xFF4CAF50);    // Mint Green

  // Stateful screen index stacks
  final List<Widget> _screens = const [
    PatientDashboardScreen(),
    DocumentUploadScreen(),
    FamilyManagementScreen(),
    PastRecordsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: _accentGreen.withOpacity(0.25),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              );
            }
            return TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Colors.grey[600],
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primaryGreen);
            }
            return IconThemeData(color: Colors.grey[600]);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          elevation: 8,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.cloud_upload_outlined),
              selectedIcon: Icon(Icons.cloud_upload_rounded),
              label: 'Upload',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Family',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'Past Records',
            ),
          ],
        ),
      ),
    );
  }
}
