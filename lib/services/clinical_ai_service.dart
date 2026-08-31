import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Enum specifying doctor preference for LLM summarization model selection.
enum SummarizerModelMode {
  autoFineTunedFirst,
  forceFineTuned,
  forceBaseModel,
}

/// Extension for user-friendly display labels and technical model tags.
extension SummarizerModelModeX on SummarizerModelMode {
  String get label {
    switch (this) {
      case SummarizerModelMode.autoFineTunedFirst:
        return '⚡ Auto (Fine-Tuned First)';
      case SummarizerModelMode.forceFineTuned:
        return '🎯 Fine-Tuned (gemma-summarizer)';
      case SummarizerModelMode.forceBaseModel:
        return '🌐 Base Model (gemma2:2b)';
    }
  }

  String get shortTag {
    switch (this) {
      case SummarizerModelMode.autoFineTunedFirst:
        return 'Auto';
      case SummarizerModelMode.forceFineTuned:
        return 'Fine-Tuned';
      case SummarizerModelMode.forceBaseModel:
        return 'Base Model';
    }
  }
}

/// Model class storing the structured trilingual analysis of clinical logs.
class ClinicalAnalysisResult {
  final String extractedConditions;
  final String activePrescriptions;
  final String plainSummaryTranslations;
  final String rawResponse;
  final String modelUsed;
  final bool isFineTuned;

  ClinicalAnalysisResult({
    required this.extractedConditions,
    required this.activePrescriptions,
    required this.plainSummaryTranslations,
    required this.rawResponse,
    this.modelUsed = 'gemma2:2b',
    this.isFineTuned = false,
  });

  /// Robust regex parser designed to segment the Ollama responses based on section headers.
  factory ClinicalAnalysisResult.fromResponse(
    String text, {
    String modelUsed = 'gemma2:2b',
    bool isFineTuned = false,
  }) {
    final conditionsReg = RegExp(
      r'1\.\s*(?:Extracted\s+)?Conditions:\s*(.*?)(?=(?:2\.\s*(?:Active\s+)?Prescriptions:)|$)',
      dotAll: true,
      caseSensitive: false,
    );
    final prescriptionsReg = RegExp(
      r'2\.\s*(?:Active\s+)?Prescriptions:\s*(.*?)(?=(?:3\.\s*(?:Plain-Language\s+)?Summary\s*(?:&\s*Translations)?)|(?:3\.\s*Clinical\s+Course\s*&\s*Notes:)|$)',
      dotAll: true,
      caseSensitive: false,
    );
    final summaryReg = RegExp(
      r'3\.\s*(?:(?:Plain-Language\s+)?Summary\s*(?:&\s*Translations)?|Clinical\s+Course\s*&\s*Notes):\s*(.*)',
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
        modelUsed: modelUsed,
        isFineTuned: isFineTuned,
      );
    }

    return ClinicalAnalysisResult(
      extractedConditions: cond.isNotEmpty ? cond : 'None extracted',
      activePrescriptions: presc.isNotEmpty ? presc : 'None extracted',
      plainSummaryTranslations: summ.isNotEmpty ? summ : 'None extracted',
      rawResponse: text,
      modelUsed: modelUsed,
      isFineTuned: isFineTuned,
    );
  }
}

/// Service managing communication with local & hosted Ollama instances, fine-tuned summarizer models, and fallback routing.
class ClinicalAiService {
  ClinicalAiService._privateConstructor();
  static final ClinicalAiService instance = ClinicalAiService._privateConstructor();

  // --- CLOUD HOSTING & SELF-HEALING FAILOVER SCHEMATIC ---
  static const String _hostedBaseUrl = 'http://34.30.122.172:11434';
  static bool useHostedByDefault = true;

  // Model identifier constants
  static const String fineTunedModelPrimary = 'gemma-summarizer';
  static const String fineTunedModelAlias = 'history-summarizer';
  static const String baseModelDefault = 'gemma2:2b';

  // Global default preference
  SummarizerModelMode selectedModelPreference = SummarizerModelMode.autoFineTunedFirst;

  // Dynamically resolve Ollama host address:
  static String get _ollamaUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:11434/api/generate';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:11434/api/generate';
    }
    return 'http://127.0.0.1:11434/api/generate';
  }

  /// Executes model inference targeting a specified model name.
  Future<Map<String, dynamic>> _executeAiInference({
    required String prompt,
    required String modelName,
    String? format,
  }) async {
    final Map<String, dynamic> requestBody = {
      'model': modelName,
      'prompt': prompt,
      'stream': false,
      if (format != null) 'format': format,
    };

    final bodyBytes = utf8.encode(jsonEncode(requestBody));

    // Try Hosted Cloud Gateway first if enabled
    if (useHostedByDefault && _hostedBaseUrl.isNotEmpty) {
      final hostedUrl = '$_hostedBaseUrl/api/generate';
      try {
        debugPrint('Attempting cloud AI inference targeting model [$modelName] at: $hostedUrl');
        final response = await http.post(
          Uri.parse(hostedUrl),
          headers: {'Content-Type': 'application/json'},
          body: bodyBytes,
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          debugPrint('Inference succeeded on cloud hosted model [$modelName].');
          return decoded;
        } else {
          debugPrint('Cloud model returned status code: ${response.statusCode}. Falling back to local...');
        }
      } catch (e) {
        debugPrint('Cloud hosted model unreachable: $e. Initiating local failover...');
      }
    }

    // Local Device Fallback path
    final localUrl = _ollamaUrl;
    debugPrint('Executing local device inference targeting model [$modelName] at: $localUrl');
    final response = await http.post(
      Uri.parse(localUrl),
      headers: {'Content-Type': 'application/json'},
      body: bodyBytes,
    ).timeout(const Duration(minutes: 2));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      debugPrint('Inference succeeded on local device model [$modelName].');
      return decoded;
    } else {
      throw Exception('Model [$modelName] failed on Ollama. Status: ${response.statusCode}. Response: ${response.body}');
    }
  }

  /// Intelligent inference wrapper implementing Auto Fine-Tuned -> Base Model fallback routing.
  Future<ClinicalAnalysisResult> executeSummarizationWithFallback({
    required String prompt,
    SummarizerModelMode? modeOverride,
    String? format,
  }) async {
    final mode = modeOverride ?? selectedModelPreference;

    if (mode == SummarizerModelMode.forceBaseModel) {
      final res = await _executeAiInference(prompt: prompt, modelName: baseModelDefault, format: format);
      final text = res['response'] as String? ?? '';
      return ClinicalAnalysisResult.fromResponse(text, modelUsed: 'Base Model ($baseModelDefault)', isFineTuned: false);
    }

    if (mode == SummarizerModelMode.forceFineTuned) {
      try {
        final res = await _executeAiInference(prompt: prompt, modelName: fineTunedModelPrimary, format: format);
        final text = res['response'] as String? ?? '';
        return ClinicalAnalysisResult.fromResponse(text, modelUsed: 'Fine-Tuned ($fineTunedModelPrimary)', isFineTuned: true);
      } catch (e) {
        // Try fallback alias if primary name fails
        try {
          final res = await _executeAiInference(prompt: prompt, modelName: fineTunedModelAlias, format: format);
          final text = res['response'] as String? ?? '';
          return ClinicalAnalysisResult.fromResponse(text, modelUsed: 'Fine-Tuned ($fineTunedModelAlias)', isFineTuned: true);
        } catch (_) {
          rethrow;
        }
      }
    }

    // Auto Mode: Tries fine-tuned first, falls back to base model seamlessly
    try {
      debugPrint('Auto Mode: Attempting fine-tuned model [$fineTunedModelPrimary]...');
      final res = await _executeAiInference(prompt: prompt, modelName: fineTunedModelPrimary, format: format);
      final text = res['response'] as String? ?? '';
      return ClinicalAnalysisResult.fromResponse(text, modelUsed: 'Fine-Tuned ($fineTunedModelPrimary)', isFineTuned: true);
    } catch (e1) {
      debugPrint('Primary fine-tuned model [$fineTunedModelPrimary] unavailable ($e1). Trying alias [$fineTunedModelAlias]...');
      try {
        final res = await _executeAiInference(prompt: prompt, modelName: fineTunedModelAlias, format: format);
        final text = res['response'] as String? ?? '';
        return ClinicalAnalysisResult.fromResponse(text, modelUsed: 'Fine-Tuned ($fineTunedModelAlias)', isFineTuned: true);
      } catch (e2) {
        debugPrint('Fine-tuned models unavailable ($e2). Initiating automatic fallback to base model [$baseModelDefault]...');
        final res = await _executeAiInference(prompt: prompt, modelName: baseModelDefault, format: format);
        final text = res['response'] as String? ?? '';
        return ClinicalAnalysisResult.fromResponse(
          text,
          modelUsed: 'Base Model ($baseModelDefault) [Fallback]',
          isFineTuned: false,
        );
      }
    }
  }

  /// Sends a prompt to summarize raw OPD patient records for patients.
  Future<ClinicalAnalysisResult> analyzeOpdNotes(String rawNotes, {SummarizerModelMode? modelMode}) async {
    final prompt = "You are a patient jargon explainer engine. Review the following clinical timeline. Provide a simple, patient-friendly summary in plain English. Format your response exactly as follows:\n"
        "1. Extracted Conditions: [List diagnosed conditions in simple terms]*\n"
        "2. Active Prescriptions: [List active medications and dosages]*\n"
        "3. Plain-Language Summary: [Write a 2-3 sentence simple explanation of the diagnosis and instructions. Do not include Sinhala or Tamil translations]*\n"
        "Do not diagnose. Extract strictly from the provided text. Clinical Data: $rawNotes";

    return executeSummarizationWithFallback(prompt: prompt, modeOverride: modelMode);
  }

  /// Sends longitudinal patient records to fine-tuned model for practitioner handover synthesis.
  Future<ClinicalAnalysisResult> analyzePatientHistoryForDoctor(String rawNotes, {SummarizerModelMode? modelMode}) async {
    final prompt = "You are a professional clinical assistant for a doctor. Review the following patient medical records. Provide a detailed, professional clinical summary. Format your response exactly as follows:\n"
        "1. Extracted Conditions: [List medical conditions professionally]*\n"
        "2. Active Prescriptions: [List active medications, dosages, and regimens]*\n"
        "3. Clinical Course & Notes: [Write a professional clinical synthesis of the patient's medical history, status, and progression]*\n"
        "\n"
        "Follow these strict clinical rules for the summary:\n"
        "- Remove repeated information. Each diagnosis, symptom, investigation, or treatment should appear only once unless repetition is required to describe progression.\n"
        "- Improve organization. Present information in a logical clinical flow (history -> recent events -> management -> pending issues) instead of jumping between conditions.\n"
        "- Use concise clinical language. Reduce phrases like 'The patient presents...' and 'The patient reports...'. Write in an information-dense style.\n"
        "- Ensure there are no contradictions. Verify that symptoms and findings remain consistent throughout the summary.\n"
        "- Preserve diagnostic uncertainty. Keep terms such as 'possible', 'suspected', 'cannot rule out', and 'likely' where appropriate. Do not promote suspected diagnoses to confirmed ones.\n"
        "- Retain all clinically relevant information while removing redundancy.\n"
        "- Do NOT invent, assume, or infer medical facts. Only summarize information explicitly documented.\n"
        "- The final summary must read like a clinical handover for another healthcare professional, making it quick to understand during patient review.\n"
        "- Keep the summary concise (approximately 150-250 words total).\n"
        "\n"
        "Records to summarize:\n"
        "$rawNotes";

    return executeSummarizationWithFallback(prompt: prompt, modeOverride: modelMode);
  }

  /// Parses a doctor's messy shorthand note into a structured PrescriptionDraft.
  Future<PrescriptionDraft> parseShorthandNote(String shorthandNote, {SummarizerModelMode? modelMode}) async {
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

    try {
      final analysisRes = await executeSummarizationWithFallback(prompt: prompt, modeOverride: modelMode, format: 'json');
      final String responseText = analysisRes.rawResponse;
      final Map<String, dynamic> parsedJson = jsonDecode(responseText) as Map<String, dynamic>;
      return PrescriptionDraft.fromJson(parsedJson);
    } catch (e) {
      debugPrint('Error parsing shorthand JSON: $e');
      return PrescriptionDraft.empty();
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
