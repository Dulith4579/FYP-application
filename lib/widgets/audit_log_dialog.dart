import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class AuditLogDialog extends StatelessWidget {
  final String patientId;

  const AuditLogDialog({super.key, required this.patientId});

  static void show(BuildContext context, String patientId) {
    showDialog(
      context: context,
      builder: (context) => AuditLogDialog(patientId: patientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          Icon(Icons.history_edu_rounded, color: primaryGreen, size: 28),
          const SizedBox(width: 12),
          const Text(
            'Security Access Logs',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Firebase.apps.isEmpty
            ? _buildMockAuditList(isDark)
            : _buildStreamAuditList(isDark, primaryGreen),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMockAuditList(bool isDark) {
    final mockAudits = [
      {
        'action': 'AUTHORIZED_SESSION',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'actorRole': 'patient',
        'details': 'Authorized secure session link with Dr. Ruwan Gunawardena (License: SLMC-8829) and shared E2EE key.',
        'blockIndex': 1,
        'blockHash': 'a3f890b712c4e56789abcdef12345678',
      },
      {
        'action': 'VIEWED_RECORDS',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
        'actorRole': 'doctor',
        'details': 'Decrypted patient E2EE session key and viewed clinical records history.',
        'blockIndex': 2,
        'blockHash': 'b4e911c823d5f67890bcdef123456789',
      },
      {
        'action': 'CREATED_RECORD',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
        'actorRole': 'doctor',
        'details': 'Created and cryptographically signed timeline record log_889211 for Type 2 Diabetes Mellitus.',
        'blockIndex': 3,
        'blockHash': 'c5f022d934e6f78901cdef1234567890',
      },
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: mockAudits.length,
      itemBuilder: (context, index) {
        final audit = mockAudits[index];
        return _buildAuditCard(
          action: audit['action'] as String,
          timestamp: audit['timestamp'] as DateTime,
          details: audit['details'] as String,
          actorRole: audit['actorRole'] as String,
          blockIndex: audit['blockIndex'] as int,
          blockHash: audit['blockHash'] as String,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildStreamAuditList(bool isDark, Color primaryGreen) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs;
        if (snapshot.hasError || docs == null || docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No Security Receipts Yet',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final blockchainMap = data['blockchain'] as Map<String, dynamic>?;
            final blockIndex = blockchainMap?['blockIndex'] as int? ?? (docs.length - index);
            final blockHash = blockchainMap?['blockHash'] as String? ?? '0x88f91a27e4b3c2...';

            return _buildAuditCard(
              action: data['action'] ?? 'ACCESS',
              timestamp: timestamp,
              details: data['details'] ?? 'Access logged.',
              actorRole: data['actorRole'] ?? 'unknown',
              blockIndex: blockIndex,
              blockHash: blockHash,
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildAuditCard({
    required String action,
    required DateTime timestamp,
    required String details,
    required String actorRole,
    required int blockIndex,
    required String blockHash,
    required bool isDark,
  }) {
    Color actionColor;
    IconData actionIcon;
    switch (action) {
      case 'AUTHORIZED_SESSION':
        actionColor = Colors.green;
        actionIcon = Icons.vpn_key_rounded;
        break;
      case 'VIEWED_RECORDS':
        actionColor = Colors.blue;
        actionIcon = Icons.visibility_rounded;
        break;
      case 'CREATED_RECORD':
        actionColor = Colors.purple;
        actionIcon = Icons.add_moderator_rounded;
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.info_outline_rounded;
    }

    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    final hashSnippet = blockHash.length > 8 ? blockHash.substring(0, 8) : blockHash;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(actionIcon, color: actionColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  action,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: actionColor,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              details,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Actor Role: ${actorRole.toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: actionColor,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_rounded, size: 11, color: isDark ? Colors.cyanAccent : Colors.teal[700]),
                      const SizedBox(width: 4),
                      Text(
                        'BLOCK #$blockIndex • SHA256: 0x$hashSnippet...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.cyanAccent : Colors.teal[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
