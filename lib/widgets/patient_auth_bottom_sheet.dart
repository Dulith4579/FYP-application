import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// A native Material 3 modal bottom sheet that facilitates real-time
/// doctor-patient session authorization.
/// 
/// Once the patient scans a doctor's session QR code, this bottom sheet is
/// presented to request granular clinical data access permissions.
/// 
/// Real-time Synchronization Design Pattern:
/// The doctor's frontend terminal listens to a stream on the session document
/// `sessions/$sessionId`. Once this widget updates the status to 'authorized',
/// the doctor's interface will automatically trigger a state transition,
/// navigating them into the patient's record view.
class PatientAuthBottomSheet extends StatefulWidget {
  final String currentSessionId;
  final String patientId;
  final String doctorName;
  final String licenseNumber;

  const PatientAuthBottomSheet({
    super.key,
    required this.currentSessionId,
    this.patientId = 'patient_014172',
    this.doctorName = 'Dr. Ruwan Gunawardena',
    this.licenseNumber = 'SLMC-8829',
  });

  /// Helper method to easily display this bottom sheet from any context.
  static Future<void> show({
    required BuildContext context,
    required String sessionId,
    String patientId = 'patient_014172',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PatientAuthBottomSheet(
          currentSessionId: sessionId,
          patientId: patientId,
        ),
      ),
    );
  }

  @override
  State<PatientAuthBottomSheet> createState() => _PatientAuthBottomSheetState();
}

class _PatientAuthBottomSheetState extends State<PatientAuthBottomSheet> {
  // Access control selections
  String _selectedAccessLevel = 'Full Longitudinal History Access';
  bool _isLoading = false;

  // Colors mapping the Clinical Green Palette
  static const Color _primaryGreen = Color(0xFF1B5E20); // Deep Forest Green
  static const Color _accentGreen = Color(0xFF4CAF50);  // Mint Green
  static const Color _bgColor = Color(0xFFF5F7F5);      // Clean Light Slate/Grey
  static const Color _cardBorderColor = Color(0xFFE0E5E0);

  /// Grants access by updating the Firestore session document.
  /// 
  /// This operation updates the authorization state, which is being monitored 
  /// by the clinician's web/desktop dashboard client using an active snapshot listener.
  Future<void> _grantAccess() async {
    setState(() {
      _isLoading = true;
    });

    // Generate haptic feedback for premium mobile feel
    await HapticFeedback.mediumImpact();

    if (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: const [
                Icon(Icons.verified_user, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Demo Mode: Session Authorized (Mock Success)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.currentSessionId);

      // --- FIRESTORE WRITE SCHEMATIC FOR THESIS SNAPSHOT ROUTING ---
      // This document update triggers a server-side state change which is instantly
      // broadcast to the subscribing client (the clinician terminal) listening on
      // FirebaseFirestore.instance.collection('sessions').doc(sessionId).snapshots()
      await sessionRef.set({
        'status': 'authorized',
        'patientId': widget.patientId,
        'accessLevel': _selectedAccessLevel,
        'expiresAt': DateTime.now().add(const Duration(minutes: 15)),
        'authorizedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        // Show success animation or visual indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: const [
                Icon(Icons.verified_user, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session Authorized. Doctor terminal updating...',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context); // Close sheet
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Authorization Failed: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            spreadRadius: 1,
            offset: Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header and Doctor Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: _primaryGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Secure Diagnostic Link',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Doctor Profile Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _cardBorderColor, width: 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _primaryGreen,
                            child: const Text(
                              'DR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accentGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Verified Practitioner',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lic: ${widget.licenseNumber}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Access Control Selector Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRANULAR DATA ACCESS CONTROLS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAccessOption(
                      title: 'Full Longitudinal History Access',
                      subtitle: 'Allows reading full past clinical timelines, conditions, & drugs.',
                      value: 'Full Longitudinal History Access',
                      icon: Icons.history_edu_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildAccessOption(
                      title: 'New Diagnosis Logs Entry Only',
                      subtitle: 'Only allows creating new logs. Prevents access to historical files.',
                      value: 'New Diagnosis Logs Entry Only',
                      icon: Icons.note_add_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _grantAccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primaryGreen.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '[ Grant Access ]',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel Connection',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedAccessLevel == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAccessLevel = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(
            color: isSelected ? _accentGreen : _cardBorderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accentGreen.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryGreen : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? _primaryGreen : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<String>(
              value: value,
              groupValue: _selectedAccessLevel,
              activeColor: _primaryGreen,
              visualDensity: VisualDensity.compact,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedAccessLevel = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
