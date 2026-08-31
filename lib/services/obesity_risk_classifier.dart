import 'package:flutter/material.dart';

/// Class containing the metadata and risk level metrics derived from the classifier.
class ObesityRiskResult {
  final String category;
  final double riskPercentage; // e.g. 15, 45, 75, 95
  final Color color;
  final String label;
  final String description;
  final String recommendation;

  const ObesityRiskResult({
    required this.category,
    required this.riskPercentage,
    required this.color,
    required this.label,
    required this.description,
    required this.recommendation,
  });
}

/// Rule-based classifier executing decision tree rules from `obesity_rules.txt`.
class ObesityRiskClassifier {
  /// Predicts the obesity risk category string using exact rule thresholds from obesity_rules.txt.
  /// 
  /// Inputs:
  /// - [height]: Height in meters (e.g. 1.70)
  /// - [weight]: Weight in kilograms (e.g. 70.0)
  /// - [age]: Age in years (14 to 80)
  /// - [gender]: Gender numeric code (0.0 for Female, 1.0 for Male)
  /// - [waterIntake]: CH2O daily water consumption in Liters (1.0 to 3.0)
  /// - [physicalActivity]: FAF weekly physical activity frequency in days (0.0 to 3.0)
  /// - [screenTime]: TUE daily screen/technology usage hours (0.0 to 2.0)
  static String predictRisk({
    required double height,
    required double weight,
    required double age,
    required double gender, // 0.0 = Female, 1.0 = Male
    required double waterIntake, // CH2O
    required double physicalActivity, // FAF
    double screenTime = 1.0, // TUE
  }) {
    if (height <= 0) return "Normal_Weight";
    final double bmi = weight / (height * height);
    final double faf = physicalActivity;
    final double ch2o = waterIntake;

    if (bmi <= 29.96) {
      if (bmi <= 24.92) {
        if (bmi <= 18.48) {
          return "Insufficient_Weight";
        } else {
          // bmi > 18.48
          if (faf <= 0.91) {
            if (faf <= 0.04) {
              return "Normal_Weight";
            } else {
              return "Overweight_Level_I";
            }
          } else {
            // faf > 0.91
            return "Normal_Weight";
          }
        }
      } else {
        // bmi > 24.92 && bmi <= 29.96
        if (bmi <= 26.92) {
          if (age <= 55.12) {
            if (bmi <= 26.82) {
              return "Overweight_Level_I";
            } else {
              return "Overweight_Level_I";
            }
          } else {
            // age > 55.12
            return "Overweight_Level_II";
          }
        } else {
          // bmi > 26.92 && bmi <= 29.96
          if (bmi <= 26.97) {
            if (ch2o <= 1.39) {
              return "Overweight_Level_I";
            } else {
              return "Overweight_Level_II";
            }
          } else {
            // bmi > 26.97
            if (gender <= 0.50) {
              return "Overweight_Level_II";
            } else {
              return "Overweight_Level_II";
            }
          }
        }
      }
    } else {
      // bmi > 29.96
      if (bmi <= 34.69) {
        if (bmi <= 34.39) {
          if (bmi <= 30.05) {
            if (faf <= 0.61) {
              return "Obesity_Type_I";
            } else {
              return "Overweight_Level_II";
            }
          } else {
            // bmi > 30.05
            if (bmi <= 34.03) {
              return "Obesity_Type_I";
            } else {
              return "Obesity_Type_I";
            }
          }
        } else {
          // bmi > 34.39
          if (bmi <= 34.55) {
            return "Obesity_Type_II";
          } else {
            // bmi > 34.55
            if (ch2o <= 2.45) {
              return "Obesity_Type_I";
            } else {
              return "Obesity_Type_II";
            }
          }
        }
      } else {
        // bmi > 34.69
        if (gender <= 0.50) {
          // Female
          if (ch2o <= 1.00) {
            if (bmi <= 40.59) {
              return "Obesity_Type_II";
            } else {
              return "Obesity_Type_III";
            }
          } else {
            // ch2o > 1.00
            return "Obesity_Type_III";
          }
        } else {
          // Male (gender > 0.50)
          if (bmi <= 44.63) {
            if (bmi <= 35.19) {
              return "Obesity_Type_II";
            } else {
              return "Obesity_Type_II";
            }
          } else {
            // bmi > 44.63
            return "Obesity_Type_III";
          }
        }
      }
    }
  }

  /// Maps category string to detailed result metrics including risk percentage, status color, and clinical recommendations.
  static ObesityRiskResult getDetailedResult({
    required double height,
    required double weight,
    required double age,
    required double gender,
    required double waterIntake,
    required double physicalActivity,
    double screenTime = 1.0,
  }) {
    final category = predictRisk(
      height: height,
      weight: weight,
      age: age,
      gender: gender,
      waterIntake: waterIntake,
      physicalActivity: physicalActivity,
      screenTime: screenTime,
    );

    switch (category) {
      case "Insufficient_Weight":
        return const ObesityRiskResult(
          category: "Insufficient_Weight",
          riskPercentage: 15.0,
          color: Color(0xFF4CAF50), // Green
          label: "Insufficient Weight",
          description: "BMI is below standard healthy range.",
          recommendation: "Consult a nutritionist to ensure adequate caloric and essential nutrient intake.",
        );
      case "Normal_Weight":
        return const ObesityRiskResult(
          category: "Normal_Weight",
          riskPercentage: 15.0,
          color: Color(0xFF4CAF50), // Green
          label: "Normal Weight",
          description: "Optimal metabolic risk profile.",
          recommendation: "Maintain balanced hydration, nutritious diet, and regular daily movement.",
        );
      case "Overweight_Level_I":
        return const ObesityRiskResult(
          category: "Overweight_Level_I",
          riskPercentage: 45.0,
          color: Color(0xFFFFB300), // Amber / Yellow
          label: "Overweight Level I",
          description: "Mild elevated metabolic risk detected.",
          recommendation: "Increase physical activity frequency to >1 day/week and monitor daily hydration.",
        );
      case "Overweight_Level_II":
        return const ObesityRiskResult(
          category: "Overweight_Level_II",
          riskPercentage: 45.0,
          color: Color(0xFFFFB300), // Amber / Yellow
          label: "Overweight Level II",
          description: "Moderate elevated risk profile.",
          recommendation: "Incorporate regular aerobic exercises and reduce high-glycemic snack intake.",
        );
      case "Obesity_Type_I":
        return const ObesityRiskResult(
          category: "Obesity_Type_I",
          riskPercentage: 75.0,
          color: Color(0xFFFF9800), // Orange
          label: "Obesity Type I",
          description: "High metabolic risk indicator.",
          recommendation: "Work with a clinical practitioner on a structured weight & lifestyle management plan.",
        );
      case "Obesity_Type_II":
        return const ObesityRiskResult(
          category: "Obesity_Type_II",
          riskPercentage: 75.0,
          color: Color(0xFFFF9800), // Orange
          label: "Obesity Type II",
          description: "High metabolic risk indicator.",
          recommendation: "Schedule a comprehensive clinical screening for metabolic syndrome and cardiovascular markers.",
        );
      case "Obesity_Type_III":
        return const ObesityRiskResult(
          category: "Obesity_Type_III",
          riskPercentage: 95.0,
          color: Color(0xFFE53935), // Red
          label: "Obesity Type III",
          description: "Very high metabolic risk requiring intervention.",
          recommendation: "Immediate medical consultation recommended for specialized bariatric & metabolic care.",
        );
      default:
        return const ObesityRiskResult(
          category: "Normal_Weight",
          riskPercentage: 15.0,
          color: Color(0xFF4CAF50),
          label: "Normal Weight",
          description: "Optimal metabolic risk profile.",
          recommendation: "Maintain balanced physical habits and healthy nutrition.",
        );
    }
  }
}
