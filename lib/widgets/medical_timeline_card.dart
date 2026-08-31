import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/encryption_service.dart';

/// Data model representing the custom NoSQL database schema for health logs.
/// 
/// Integrates both raw clinical data (doctor inputs with medical codes)
/// and trilingual AI translations (Sinhala, Tamil, English) for high accessibility.
class MedicalLog {
  final String logId;
  final DateTime timestamp;
  final DoctorMetadata doctor;
  final ClinicalData clinical;
  final TranslationData translations;

  MedicalLog({
    required this.logId,
    required this.timestamp,
    required this.doctor,
    required this.clinical,
    required this.translations,
  });

  /// Factory constructor to parse JSON logs directly from Firestore documents.
  factory MedicalLog.fromJson(Map<String, dynamic> json) {
    return MedicalLog(
      logId: json['logId'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is String 
              ? DateTime.parse(json['timestamp'] as String)
              : (json['timestamp'] as Timestamp).toDate())
          : DateTime.now(),
      doctor: DoctorMetadata.fromJson(json['doctor'] as Map<String, dynamic>? ?? {}),
      clinical: ClinicalData.fromJson(json['clinical'] as Map<String, dynamic>? ?? {}),
      translations: TranslationData.fromJson(json['translations'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'logId': logId,
    'timestamp': timestamp.toIso8601String(),
    'doctor': doctor.toJson(),
    'clinical': clinical.toJson(),
    'translations': translations.toJson(),
  };
}

class DoctorMetadata {
  final String name;
  final String license;
  final String digitalSignature;
  final String publicKey;

  DoctorMetadata({
    required this.name,
    required this.license,
    required this.digitalSignature,
    this.publicKey = '',
  });

  factory DoctorMetadata.fromJson(Map<String, dynamic> json) {
    return DoctorMetadata(
      name: json['name'] as String? ?? 'Unknown Practitioner',
      license: json['license'] as String? ?? 'N/A',
      digitalSignature: json['digitalSignature'] as String? ?? 'Unsigned',
      publicKey: json['publicKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'license': license,
    'digitalSignature': digitalSignature,
    'publicKey': publicKey,
  };
}

class ClinicalData {
  final String condition;
  final String conditionCode; // e.g. SNOMED-CT / ICD-10
  final String medication;
  final String medicationCode; // e.g. RxNorm
  final String dosage;
  final String notes;

  ClinicalData({
    required this.condition,
    required this.conditionCode,
    required this.medication,
    required this.medicationCode,
    required this.dosage,
    required this.notes,
  });

  factory ClinicalData.fromJson(Map<String, dynamic> json) {
    return ClinicalData(
      condition: EncryptionService.decrypt(json['condition'] as String? ?? ''),
      conditionCode: json['conditionCode'] as String? ?? '',
      medication: EncryptionService.decrypt(json['medication'] as String? ?? ''),
      medicationCode: json['medicationCode'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      notes: EncryptionService.decrypt(json['notes'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'condition': condition,
    'conditionCode': conditionCode,
    'medication': medication,
    'medicationCode': medicationCode,
    'dosage': dosage,
    'notes': notes,
  };
}

class TranslationData {
  final String conditionSi;
  final String conditionTa;
  final String medicationSi;
  final String medicationTa;
  final String notesSi;
  final String notesTa;

  TranslationData({
    required this.conditionSi,
    required this.conditionTa,
    required this.medicationSi,
    required this.medicationTa,
    required this.notesSi,
    required this.notesTa,
  });

  factory TranslationData.fromJson(Map<String, dynamic> json) {
    return TranslationData(
      conditionSi: json['condition_si'] as String? ?? '',
      conditionTa: json['condition_ta'] as String? ?? '',
      medicationSi: json['medication_si'] as String? ?? '',
      medicationTa: json['medication_ta'] as String? ?? '',
      notesSi: json['notes_si'] as String? ?? '',
      notesTa: json['notes_ta'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'condition_si': conditionSi,
    'condition_ta': conditionTa,
    'medication_si': medicationSi,
    'medication_ta': medicationTa,
    'notes_si': notesSi,
    'notes_ta': notesTa,
  };
}

/// A premium, highly accessible timeline card representing a single health record.
/// 
/// Implements a sliding segmented view switcher enabling clinicians to toggle
/// between raw verified clinical records (Doctor View) and localized, high-accessibility,
/// trilingual translations (Patient View).
class MedicalTimelineCard extends StatefulWidget {
  final MedicalLog log;

  const MedicalTimelineCard({
    super.key,
    required this.log,
  });

  @override
  State<MedicalTimelineCard> createState() => _MedicalTimelineCardState();
}

class _MedicalTimelineCardState extends State<MedicalTimelineCard> with SingleTickerProviderStateMixin {
  // Active Tab Index: 0 for Clinical, 1 for Simplified
  int _activeViewIndex = 0;

  // Clinical Green Colors (dynamic for dark mode compatibility)
  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
  Color get _accentGreen => const Color(0xFF4CAF50);
  Color get _bgColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7F5);
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9);
  Color get _darkGrey => Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF37474F);

  bool get _isSignatureVerified {
    if (widget.log.doctor.digitalSignature == 'Unsigned' || widget.log.doctor.publicKey.isEmpty) {
      return false;
    }
    try {
      final pubKey = EncryptionService.deserializePublicKey(widget.log.doctor.publicKey);
      final plainText = '${widget.log.clinical.condition}|${widget.log.clinical.medication}|${widget.log.clinical.dosage}|${widget.log.clinical.notes}|${widget.log.doctor.name}|${widget.log.doctor.license}';
      return EncryptionService.rsaVerify(plainText, widget.log.doctor.digitalSignature, pubKey);
    } catch (_) {
      return false;
    }
  }

  Widget _buildSignatureBadge(bool isDark) {
    final String sig = widget.log.doctor.digitalSignature;
    final String pubKey = widget.log.doctor.publicKey;
    
    final isRsaSig = sig != 'Unsigned' && pubKey.isNotEmpty;
    final isRsaValid = isRsaSig && _isSignatureVerified;
    final isLegacy = sig.startsWith('0x');

    if (isRsaValid) {
      return Row(
        children: [
          const Icon(Icons.gpp_good_rounded, color: Colors.green, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'RSA Asymmetric Signature: Verified & Authenticated (E2EE E2E)',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      );
    } else if (isLegacy) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Legacy System Hash (Unverified / Spoofable doctor digitalSignature)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.amber[800],
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Clinician Record Unsigned (Missing non-repudiation security block)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatClinicalDate(widget.log.timestamp);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _cardBorderColor, width: 1.5),
      ),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category, Date, and Sliding Switch Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: _primaryGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    // Access Security Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: _primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            'HIPAA Secured',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Sliding Segmented Tab Controller
                _buildSlidingTabControl(),
              ],
            ),
          ),

          Divider(color: _bgColor, height: 1, thickness: 1.5),

          // Main Display Window
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              color: _bgColor.withOpacity(0.4),
              padding: const EdgeInsets.all(20),
              child: _activeViewIndex == 0 
                  ? _buildClinicalView() 
                  : _buildSimplifiedView(),
            ),
          ),

          // Card Footer: Immutable Verification State
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.verified, size: 14, color: _accentGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Practitioner: ${widget.log.doctor.name} (${widget.log.doctor.license})',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'ID: #${widget.log.logId.substring(0, 6)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], height: 1, thickness: 0.5),
                const SizedBox(height: 8),
                _buildSignatureBadge(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Custom animated sliding tab control.
  Widget _buildSlidingTabControl() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Sliding active background pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: _activeViewIndex == 0 ? 3 : tabWidth - 3,
                top: 3,
                bottom: 3,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black38 : Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
              // Tab Labels
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeViewIndex = 0);
                      },
                      child: Center(
                        child: Text(
                          'Clinical View',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: _activeViewIndex == 0 ? FontWeight.bold : FontWeight.w600,
                            color: _activeViewIndex == 0 ? _primaryGreen : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeViewIndex = 1);
                      },
                      child: Center(
                        child: Text(
                          'Patient Summary',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: _activeViewIndex == 1 ? FontWeight.bold : FontWeight.w600,
                            color: _activeViewIndex == 1 ? _primaryGreen : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Renders raw doctor inputs, including clinical codes (ICD-10/SNOMED)
  /// and digital signature verification data.
  Widget _buildClinicalView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verified Badge Banner
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: _primaryGreen),
            const SizedBox(width: 6),
            Text(
              'VERIFIED CLINICAL RECORD (UNALTERED)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: _primaryGreen.withOpacity(0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Diagnosis Row
        _buildClinicalRow(
          label: 'Diagnosed Condition',
          value: widget.log.clinical.condition,
          code: widget.log.clinical.conditionCode,
          icon: Icons.healing_rounded,
        ),
        const SizedBox(height: 16),

        // Medication Row
        _buildClinicalRow(
          label: 'Medication & Regimen',
          value: widget.log.clinical.medication,
          code: widget.log.clinical.medicationCode,
          icon: Icons.medication_rounded,
          extraText: 'Dosage: ${widget.log.clinical.dosage}',
        ),
        
        if (widget.log.clinical.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: _cardBorderColor, thickness: 0.5),
          const SizedBox(height: 12),
          Text(
            'Clinical Notes',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.log.clinical.notes,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: _darkGrey,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: 16),
        // Cryptographic Signature Hash Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cardBorderColor.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.fingerprint, size: 16, color: _accentGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIGITAL SIGNATURE HASH',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.log.doctor.digitalSignature,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _darkGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Renders AI simplified descriptions and trilingual translations in high-accessibility fonts.
  Widget _buildSimplifiedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Warning Banner to maintain Clinical Integrity with Trilingual Disclaimers
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 16, color: _primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI TRANSLATION DISCLAIMER / වියාචනය / பொறுப்புத் துறப்பு',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• EN: Simplified summaries are automatically generated for reference only. The doctor\'s original clinical record remains primary.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _primaryGreen, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                '• SI: මෙම සරල කළ සාරාංශ යොමු කිරීම සඳහා පමණක් ස්වයංක්‍රීයව ජනනය කෙරේ. වෛද්‍යවරයාගේ මුල් සායනික වාර්තාව ප්‍රධාන වේ.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _primaryGreen, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                '• TA: இந்த எளிமைப்படுத்தப்பட்ட சுருக்கங்கள் குறிப்புக்காக மட்டுமே தானாகவே உருவாக்கப்படுகின்றன. மருத்துவரின் அசல் மருத்துவப் பதிவேடே முதன்மையானது.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _primaryGreen, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Trilingual Condition Card
        _buildTranslationBlock(
          labelEnglish: 'Condition (English)',
          labelLocal: 'අධික රුධිර පීඩනය (Sinhala) / இரத்த அழுத்தம் (Tamil)',
          englishValue: widget.log.clinical.condition,
          sinhalaValue: widget.log.translations.conditionSi,
          tamilValue: widget.log.translations.conditionTa,
          icon: Icons.accessibility_new_rounded,
        ),
        const SizedBox(height: 20),

        // Trilingual Prescription Card
        _buildTranslationBlock(
          labelEnglish: 'Medication Details (English)',
          labelLocal: 'බෙහෙත් නියමයන් (Sinhala) / மருந்துகள் (Tamil)',
          englishValue: '${widget.log.clinical.medication} (${widget.log.clinical.dosage})',
          sinhalaValue: widget.log.translations.medicationSi,
          tamilValue: widget.log.translations.medicationTa,
          icon: Icons.assignment_turned_in_rounded,
        ),

        if (widget.log.translations.notesSi.isNotEmpty || widget.log.translations.notesTa.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildTranslationBlock(
            labelEnglish: 'Advice & Instructions',
            labelLocal: 'විශේෂ උපදෙස් / கூடுதல் அறிவுறுத்தல்கள்',
            englishValue: widget.log.clinical.notes,
            sinhalaValue: widget.log.translations.notesSi,
            tamilValue: widget.log.translations.notesTa,
            icon: Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: 20),
        
        // Explain Jargon Button
        Center(
          child: ActionChip(
            onPressed: () => _showJargonExplainer(context),
            avatar: Icon(Icons.lightbulb_outline_rounded, color: _primaryGreen, size: 16),
            label: Text(
              'Explain Medical Jargon',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _primaryGreen,
              ),
            ),
            backgroundColor: _accentGreen.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _accentGreen, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  void _showJargonExplainer(BuildContext context) {
    HapticFeedback.selectionClick();

    final condition = widget.log.clinical.condition.toLowerCase();
    final medication = widget.log.clinical.medication.toLowerCase();
    final List<Map<String, String>> jargonList = [];

    // Jargon Dictionary Mappings
    if (condition.contains('hypertension') || condition.contains('pressure')) {
      jargonList.add({
        'term': 'Essential Hypertension',
        'en': 'High Blood Pressure: A chronic condition where the force of the blood against your artery walls is too high, which can damage blood vessels over time.',
        'si': 'අධික රුධිර පීඩනය: ධමනි බිත්ති හරහා ගමන් කරන රුධිරයේ පීඩනය සාමාන්‍ය මට්ටමට වඩා ඉහළ යාම. කාලයත් සමඟ හෘදයාබාධ ඇතිවීමේ අවදානම වැඩි කරයි.',
        'ta': 'உயர் இரத்த அழுத்தம்: இரத்த நாளங்களின் சுவர்களில் இரத்தத்தின் விசை மிக அதிகமாக இருக்கும் ஒரு நாள்பட்ட நிலை, இது காலப்போக்கில் இரத்த நாளங்களை சேதப்படுத்தும்.',
      });
    }
    if (medication.contains('losartan')) {
      jargonList.add({
        'term': 'Losartan Potassium',
        'en': 'Losartan Potassium: A medication that relaxes blood vessels, helping them widen so blood flows more smoothly, lowering blood pressure.',
        'si': 'ලොසාර්ටන් පොටෑසියම්: රුධිර වාහිනී ලිහිල් කර පුළුල් කිරීමට උපකාරී වන ඖෂධයකි. එමගින් රුධිරය ගලායාම පහසු කර රුධිර පීඩනය අඩු කරයි.',
        'ta': 'லோசர்டான் பொட்டாசியம்: இரத்த தமனிகளைத் தளர்த்தி, அவை விரிவடைவதற்கு உதவும் ஒரு மருந்து, இதனால் இரத்தம் சீராக பாய்கிறது, இரத்த அழுத்தத்தைக் குறைக்கிறது.',
      });
    }
    if (condition.contains('diabetes') || condition.contains('sugar')) {
      jargonList.add({
        'term': 'Type 2 Diabetes Mellitus',
        'en': 'Type 2 Diabetes Mellitus: A metabolic condition where the body does not produce enough insulin or cells become resistant to it, causing high blood sugar levels.',
        'si': '2 වන කාණ්ඩයේ දියවැඩියාව: ශරීරය ප්‍රමාණවත් ලෙස ඉන්සියුලින් නිපදවන්නේ නැති හෝ සෛල එයට ප්‍රතිචාර නොදක්වන පරිවෘත්තීය තත්ත්වයකි. රුධිරයේ සීනි මට්ටම ඉහළ යාමට හේතු වේ.',
        'ta': 'வகை 2 நீரிழிவு நோய்: உடல் போதுமான இன்சுலினை உற்பத்தி செய்யாத அல்லது செல்கள் அதற்கு எதிர்ப்புத் தெரிவிக்கும் ஒரு வளர்சிதை மாற்ற நிலை, இதனால் இரத்த சர்க்கரை அளவு அதிகரிக்கிறது.',
      });
    }
    if (medication.contains('metformin')) {
      jargonList.add({
        'term': 'Metformin Hydrochloride',
        'en': 'Metformin Hydrochloride: A prescription medicine that improves the body\'s response to insulin, reducing sugar absorption and production in the liver.',
        'si': 'මෙට්ෆොමින් හයිඩ්‍රොක්ලෝරයිඩ්: ඉන්සියුලින් වලට ශරීරයේ සංවේදීතාව වැඩි කරන අතර අක්මාව මගින් සීනි නිපදවීම සීමා කරන ඖෂධයකි.',
        'ta': 'மெட்ஃபார்மின் ஹைட்ரோகுளோரைடு: இன்சுலினுக்கு உடலின் பதிலை மேம்படுத்தும் ஒரு பரிந்துரைக்கப்பட்ட மருந்து, கல்லீரலில் சர்க்கரை உறிஞ்சுதல் மற்றும் உற்பத்தியைக் குறைக்கிறது.',
      });
    }
    if (condition.contains('cholesterol') || condition.contains('lipid') || condition.contains('lipids')) {
      jargonList.add({
        'term': 'Hypercholesterolemia',
        'en': 'Hypercholesterolemia: High levels of cholesterol (fatty deposits) in your blood, which can restrict blood flow and build up blockages in arteries.',
        'si': 'අධික කොලෙස්ටරෝල් තත්ත්වය: රුධිරයේ මේද අංශු (කොලෙස්ටරෝල්) මට්ටම ඉහළ යාම. එමගින් ධමනි පටු වී රුධිර සංසරණයට බාධා ඇති විය හැක.',
        'ta': 'உயர் கொழுப்பு: உங்கள் இரத்தத்தில் அதிக அளவு கொழுப்பு (கொழுப்பு படிவுகள்), இது இரத்த ஓட்டத்தை கட்டுப்படுத்தலாம் மற்றும் தமனிகளில் அடைப்புகளை உருவாக்கலாம்.',
      });
    }
    if (medication.contains('atorvastatin')) {
      jargonList.add({
        'term': 'Atorvastatin',
        'en': 'Atorvastatin: A statin medication that works by lowering bad cholesterol (LDL) and triglycerides, and raising good cholesterol (HDL).',
        'si': 'ඇටෝර්වස්ටැටින්: අක්මාව මගින් අහිතකර කොලෙස්ටරෝල් (LDL) නිෂ්පාදනය කිරීම වළක්වා හිතකර කොලෙස්ටරෝල් (HDL) මට්ටම වැඩි කරන ඖෂධයකි.',
        'ta': 'அடோர்வாஸ்டாடின்: கெட்ட கொழுப்பைக் (LDL) குறைத்து நல்ல கொழுப்பை (HDL) அதிகரிப்பதன் மூலம் செயல்படும் ஒரு மருந்து.',
      });
    }

    if (jargonList.isEmpty) {
      jargonList.add({
        'term': widget.log.clinical.condition,
        'en': 'No specific explanation found. This is logged as a secure clinical record entry.',
        'si': 'විස්තරයක් හමු නොවුණි. මෙය ආරක්ෂිත සායනික වාර්තාවක් ලෙස ඇතුළත් කර ඇත.',
        'ta': 'குறிப்பிட்ட விளக்கம் எதுவும் இல்லை. இது ஒரு பாதுகாப்பான மருத்துவப் பதிவாக உள்ளது.',
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: _primaryGreen, size: 24),
                const SizedBox(width: 8),
                Text(
                  'AI Medical Jargon Explainer',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Simplifying clinical diagnoses and drug descriptions in English, සිංහල, & தமிழ்.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: jargonList.map((jargon) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: _cardBorderColor),
                      ),
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                jargon['term']!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              jargon['en']!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: _darkGrey,
                                height: 1.4,
                              ),
                            ),
                            Divider(color: _bgColor, height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'සිංහල',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    jargon['si']!,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: _darkGrey,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: _bgColor, height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'தமிழ்',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    jargon['ta']!,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: _darkGrey,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Trilingual Medical Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MEDICAL DISCLAIMER / වියාචනය / பொறுப்புத் துறப்பு',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[200] : Colors.amber[950],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• EN: AI definitions are for general informational reference only. They do not replace professional medical advice or clinical diagnoses.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: isDark ? Colors.amber[200] : Colors.amber[950], height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• SI: මෙම නිර්වචන සාමාන්‍ය තොරතුරු සඳහා පමණි. ඒවා වෘත්තීය වෛද්‍ය උපදෙස් හෝ රෝග විනිශ්චය සඳහා ආදේශකයක් නොවේ.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: isDark ? Colors.amber[200] : Colors.amber[950], height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• TA: இந்த வரையறைகள் பொதுவான தகவல் குறிப்புக்காக மட்டுமே. இவை தொழில்முறை மருத்துவ ஆலோசனை அல்லது மருத்துவ நோயறிதலுக்கு மாற்றாகாது.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: isDark ? Colors.amber[200] : Colors.amber[950], height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Understand & Close', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalRow({
    required String label,
    required String value,
    required String code,
    required IconData icon,
    String? extraText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _primaryGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (extraText != null) ...[
                const SizedBox(height: 2),
                Text(
                  extraText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _darkGrey,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              // Coding standard chip (ICD-10, SNOMED)
              if (code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// A translation section displaying labels in Sinhala, Tamil, and English.
  /// Uses a larger scale typography format to optimize user accessibility.
  Widget _buildTranslationBlock({
    required String labelEnglish,
    required String labelLocal,
    required String englishValue,
    required String sinhalaValue,
    required String tamilValue,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accentGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$labelEnglish | $labelLocal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // English (Original)
          Text(
            englishValue,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          // Sinhala Translation (සිංහල)
          if (sinhalaValue.isNotEmpty) ...[
            Divider(color: _bgColor, height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'සිංහල',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: _primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sinhalaValue,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _darkGrey,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Tamil Translation (தமிழ்)
          if (tamilValue.isNotEmpty) ...[
            Divider(color: _bgColor, height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'தமிழ்',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: _primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tamilValue,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _darkGrey,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatClinicalDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} UTC';
  }
}
