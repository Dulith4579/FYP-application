import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model class storing the structured trilingual analysis of clinical logs.
class ClinicalAnalysisResult {
  final String extractedConditions;
  final String activePrescriptions;
  final String plainSummaryTranslations;
  final String rawResponse;

  ClinicalAnalysisResult({
    required this.extractedConditions,
    required this.activePrescriptions,
    required this.plainSummaryTranslations,
    required this.rawResponse,
  });

  /// Robust regex parser designed to segment the Ollama responses based on section headers.
  factory ClinicalAnalysisResult.fromResponse(String text) {
    final conditionsReg = RegExp(
      r'1\.\s*(?:Extracted\s+)?Conditions:\s*(.*?)(?=(?:2\.\s*(?:Active\s+)?Prescriptions:)|$)',
      dotAll: true,
      caseSensitive: false,
    );
    final prescriptionsReg = RegExp(
      r'2\.\s*(?:Active\s+)?Prescriptions:\s*(.*?)(?=(?:3\.\s*(?:Plain-Language\s+)?Summary\s*&\s*Translations:)|$)',
      dotAll: true,
      caseSensitive: false,
    );
    final summaryReg = RegExp(
      r'3\.\s*(?:Plain-Language\s+)?Summary\s*&\s*Translations:\s*(.*)',
      dotAll: true,
      caseSensitive: false,
    );

    final conditionsMatch = conditionsReg.firstMatch(text);
    final prescriptionsMatch = prescriptionsReg.firstMatch(text);
    final summaryMatch = summaryReg.firstMatch(text);

    String cond = conditionsMatch?.group(1)?.trim() ?? '';
    String presc = prescriptionsMatch?.group(1)?.trim() ?? '';
    String summ = summaryMatch?.group(1)?.trim() ?? '';

    // If parsing fails to segment, put the full text into plainSummaryTranslations for safety
    if (cond.isEmpty && presc.isEmpty && summ.isEmpty) {
      return ClinicalAnalysisResult(
        extractedConditions: 'Not segmented. Refer to raw summary.',
        activePrescriptions: 'Not segmented. Refer to raw summary.',
        plainSummaryTranslations: text,
        rawResponse: text,
      );
    }

    return ClinicalAnalysisResult(
      extractedConditions: cond.isNotEmpty ? cond : 'None extracted',
      activePrescriptions: presc.isNotEmpty ? presc : 'None extracted',
      plainSummaryTranslations: summ.isNotEmpty ? summ : 'None extracted',
      rawResponse: text,
    );
  }
}

/// Service managing communication with the local Ollama instance running Gemma 2.
class ClinicalAiService {
  ClinicalAiService._privateConstructor();
  static final ClinicalAiService instance = ClinicalAiService._privateConstructor();

  // Dynamically resolve Ollama host address:
  // - Web / Desktop / iOS: http://127.0.0.1:11434
  // - Android Emulator: http://10.0.2.2:11434
  static String get _ollamaUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:11434/api/generate';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:11434/api/generate';
    }
    return 'http://127.0.0.1:11434/api/generate';
  }

  static const String _modelName = 'gemma2:2b';

  /// Sends a prompt to Ollama to summarize the raw patient records.
  Future<ClinicalAnalysisResult> analyzeOpdNotes(String rawNotes) async {
    final prompt = "You are a clinical summarization engine for a Sri Lankan healthcare app. Review the following fragmented clinical timeline. Provide a highly interpretable summary. You MUST format your response exactly as follows:\n"
        "1. Extracted Conditions: [List exact medical conditions]*\n"
        "2. Active Prescriptions: [List exact medications and dosages]*\n"
        "3. Plain-Language Summary & Translations: [Write a 2-3 sentence simple explanation. Translate key medical terms into Sinhala and Tamil]*\n"
        "Do not diagnose. Extract strictly from the provided text. Clinical Data: $rawNotes";

    final Map<String, dynamic> requestBody = {
      'model': _modelName,
      'prompt': prompt,
      'stream': false,
    };

    final response = await http.post(
      Uri.parse(_ollamaUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      // Decode bytes using UTF-8 to handle trilingual characters correctly
      final Map<String, dynamic> responseJson = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final String responseText = responseJson['response'] as String? ?? '';
      return ClinicalAnalysisResult.fromResponse(responseText);
    } else {
      throw Exception('Failed to connect to local Ollama. HTTP Status: ${response.statusCode}');
    }
  }

  /// Parses a doctor's messy shorthand note into a strongly-typed PrescriptionDraft.
  /// 
  /// Instructs Ollama to output JSON, which is then validated and cast on the client.
  Future<PrescriptionDraft> parseShorthandNote(String shorthandNote) async {
    final prompt = "You are a clinical parser for a healthcare app. Parse the following messy doctor's shorthand note into a structured JSON prescription.\n"
        "You must return a JSON object matching this exact schema:\n"
        "{\n"
        "  \"condition\": \"string representing the diagnosed condition\",\n"
        "  \"medication\": \"string representing the prescribed medication name\",\n"
        "  \"dosage\": \"string representing the dosage regimen and frequencies\",\n"
        "  \"notes\": \"string representing patient notes and instructions\",\n"
        "  \"warnings\": \"string listing any potential drug interaction warnings or recommendations, or empty if none\"\n"
        "}\n"
        "Do not diagnose or invent information beyond the shorthand note. If warning information is not applicable, set it to empty.\n"
        "Shorthand Note: $shorthandNote";

    final response = await http.post(
      Uri.parse(_ollamaUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _modelName,
        'prompt': prompt,
        'format': 'json',
        'stream': false,
      }),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      final responseJson = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final responseText = responseJson['response'] as String? ?? '';
      
      try {
        final Map<String, dynamic> parsedJson = jsonDecode(responseText) as Map<String, dynamic>;
        return PrescriptionDraft.fromJson(parsedJson);
      } catch (e) {
        // Fallback to empty if JSON parsing fails to avoid app crashes
        return PrescriptionDraft.empty();
      }
    } else {
      throw Exception('Failed to connect to local Ollama. HTTP Status: ${response.statusCode}');
    }
  }
}

/// Strongly-typed client-side model representing a generated AI draft for clinician review.
class PrescriptionDraft {
  final String condition;
  final String medication;
  final String dosage;
  final String notes;
  final String warnings;

  PrescriptionDraft({
    required this.condition,
    required this.medication,
    required this.dosage,
    required this.notes,
    required this.warnings,
  });

  /// Safely parses JSON schema fields with fallbacks to empty strings.
  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) {
    return PrescriptionDraft(
      condition: json['condition']?.toString() ?? '',
      medication: json['medication']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      warnings: json['warnings']?.toString() ?? '',
    );
  }

  /// Empty constructor for parser fallback states.
  factory PrescriptionDraft.empty() {
    return PrescriptionDraft(
      condition: '',
      medication: '',
      dosage: '',
      notes: '',
      warnings: '',
    );
  }
}
