import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_phr_service.dart';

/// Screen allowing users to manage family profiles and dependent accounts.
/// 
/// Essential for pediatric care (children) and geriatric care (elderly parents),
/// enabling a primary caregiver to consent to data requests on their behalf.
class FamilyManagementScreen extends StatefulWidget {
  final String mainUserId;

  const FamilyManagementScreen({
    super.key,
    this.mainUserId = 'patient_014172',
  });

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  // Clinical Green Palette
  static const Color _primaryGreen = Color(0xFF1B5E20);   // Deep Forest Green
  static const Color _accentGreen = Color(0xFF4CAF50);    // Mint Green
  static const Color _bgColor = Color(0xFFF5F7F5);        // Clean Light Slate/Grey
  static const Color _cardBorderColor = Color(0xFFC8E6C9);

  // Local state list for demo mode fallbacks
  final List<Map<String, String>> _localDependents = [
    {'name': 'Nirmala Gunawardena', 'relationship': 'Mother', 'age': '64'},
    {'name': 'Kasun Gunawardena', 'relationship': 'Child', 'age': '8'},
  ];

  /// Launches the interactive sheet to capture and save a new dependent.
  void _openAddDependentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddDependentFormSheet(
          mainUserId: widget.mainUserId,
          onLocalSave: (name, relationship, age) {
            setState(() {
              _localDependents.add({
                'name': name,
                'relationship': relationship,
                'age': age,
              });
            });
          },
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Family dependent added successfully.'),
                backgroundColor: _primaryGreen,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Family & Dependents',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informational Header Card with high contrast
            Container(
              padding: const EdgeInsets.all(20),
              color: _primaryGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Connected Profiles',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link and manage health records for senior citizens, children, or dependents requiring medical custody.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Live List of Dependents
            Expanded(
              child: Firebase.apps.isEmpty
                  ? ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _localDependents.length,
                      itemBuilder: (context, index) {
                        final data = _localDependents[index];
                        final String name = data['name'] ?? 'Name Unavailable';
                        final String relationship = data['relationship'] ?? 'Dependent';
                        final String age = data['age'] ?? 'N/A';
                        return _buildDependentCard(name, relationship, age);
                      },
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebasePhrService.instance.getDependents(widget.mainUserId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs;
                        if (snapshot.hasError || docs == null || docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final String name = data['name'] ?? 'Name Unavailable';
                            final String relationship = data['relationship'] ?? 'Dependent';
                            final String age = data['age'] ?? 'N/A';
                            return _buildDependentCard(name, relationship, age);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDependentBottomSheet,
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Dependent',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDependentCard(String name, String relationship, String age) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _cardBorderColor, width: 1),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: _primaryGreen.withOpacity(0.1),
          child: Icon(
            relationship.toLowerCase() == 'child' 
                ? Icons.child_care_rounded 
                : Icons.elderly_rounded,
            color: _primaryGreen,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                relationship,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$age Years Old',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: _primaryGreen,
        ),
        onTap: () {
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Dependents Linked',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to link a pediatric/geriatric family record profile.',
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
}

/// A validated input form component configured as a slide-up bottom sheet
/// to capture family member metadata.
class AddDependentFormSheet extends StatefulWidget {
  final String mainUserId;
  final VoidCallback onSuccess;
  final void Function(String name, String relationship, String age)? onLocalSave;

  const AddDependentFormSheet({
    super.key,
    required this.mainUserId,
    required this.onSuccess,
    this.onLocalSave,
  });

  @override
  State<AddDependentFormSheet> createState() => _AddDependentFormSheetState();
}

class _AddDependentFormSheetState extends State<AddDependentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  
  String _selectedRelationship = 'Child';
  bool _isSaving = false;

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF5F7F5);

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    await HapticFeedback.mediumImpact();

    if (Firebase.apps.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (widget.onLocalSave != null) {
        widget.onLocalSave!(
          _nameController.text.trim(),
          _selectedRelationship,
          _ageController.text.trim(),
        );
      }
      widget.onSuccess();
      return;
    }

    try {
      await FirebasePhrService.instance.addDependent(
        mainUserId: widget.mainUserId,
        name: _nameController.text.trim(),
        relationship: _selectedRelationship,
        age: _ageController.text.trim(),
      );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save dependent: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Family Profile',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(fontFamily: 'Inter'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryGreen, width: 2),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter the dependent\'s full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Relationship Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedRelationship,
                    decoration: InputDecoration(
                      labelText: 'Relationship',
                      labelStyle: const TextStyle(fontFamily: 'Inter'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryGreen, width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Child', child: Text('Child')),
                      DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                      DropdownMenuItem(value: 'Father', child: Text('Father')),
                      DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRelationship = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Age Field
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Age',
                      labelStyle: const TextStyle(fontFamily: 'Inter'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryGreen, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter age';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // Submission Button
            ElevatedButton(
              onPressed: _isSaving ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Dependent Profile',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
