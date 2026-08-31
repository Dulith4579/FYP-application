import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/obesity_risk_classifier.dart';

/// A self-contained, responsive, interactive Metabolic Risk Calculator card widget using text input fields.
class MetabolicRiskCalculatorCard extends StatefulWidget {
  const MetabolicRiskCalculatorCard({super.key});

  @override
  State<MetabolicRiskCalculatorCard> createState() => _MetabolicRiskCalculatorCardState();
}

class _MetabolicRiskCalculatorCardState extends State<MetabolicRiskCalculatorCard> {
  // Input parameters state with standard defaults
  double _gender = 0.0; // 0.0 = Female, 1.0 = Male

  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _waterController;
  late TextEditingController _activityController;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: '25');
    _heightController = TextEditingController(text: '1.70');
    _weightController = TextEditingController(text: '70.0');
    _waterController = TextEditingController(text: '2.0');
    _activityController = TextEditingController(text: '1.5');
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _waterController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  // Resets all input parameters to baseline defaults
  void _resetInputs() {
    setState(() {
      _gender = 0.0;
      _ageController.text = '25';
      _heightController.text = '1.70';
      _weightController.text = '70.0';
      _waterController.text = '2.0';
      _activityController.text = '1.5';
    });
  }

  double _parseVal(TextEditingController controller, double fallback) {
    final text = controller.text.trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }

  double get _age => _parseVal(_ageController, 25.0);
  double get _height => _parseVal(_heightController, 1.70);
  double get _weight => _parseVal(_weightController, 70.0);
  double get _waterIntake => _parseVal(_waterController, 2.0);
  double get _physicalActivity => _parseVal(_activityController, 1.5);

  double get _currentBmi {
    final h = _height;
    if (h <= 0) return 0;
    return _weight / (h * h);
  }

  void _stepValue(TextEditingController controller, double step, double minVal, double maxVal, int decimalPlaces) {
    final current = _parseVal(controller, minVal);
    double newVal = current + step;
    if (newVal < minVal) newVal = minVal;
    if (newVal > maxVal) newVal = maxVal;
    setState(() {
      controller.text = decimalPlaces == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(decimalPlaces);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
    final cardBorderColor = isDark ? const Color(0xFF2E7D32) : const Color(0xFFC8E6C9);

    final ObesityRiskResult riskResult = ObesityRiskClassifier.getDetailedResult(
      height: _height,
      weight: _weight,
      age: _age,
      gender: _gender,
      waterIntake: _waterIntake,
      physicalActivity: _physicalActivity,
    );

    final double bmiValue = _currentBmi;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorderColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title and subtitle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      color: primaryGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Metabolic Risk Calculator',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rule-based PHR risk classification',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Gender Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGenderButton(
                          label: 'Female',
                          icon: Icons.female_rounded,
                          isSelected: _gender == 0.0,
                          onTap: () => setState(() => _gender = 0.0),
                          activeColor: Colors.pinkAccent,
                          isDark: isDark,
                        ),
                        _buildGenderButton(
                          label: 'Male',
                          icon: Icons.male_rounded,
                          isSelected: _gender == 1.0,
                          onTap: () => setState(() => _gender = 1.0),
                          activeColor: Colors.blueAccent,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Text Input Fields Grid (2 columns on wider screens, 1 column on small screens)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final children = [
                    _buildInputFieldTile(
                      title: 'Age',
                      controller: _ageController,
                      unit: 'years',
                      icon: Icons.cake_outlined,
                      isDark: isDark,
                      primaryColor: primaryGreen,
                      minVal: 14.0,
                      maxVal: 80.0,
                      step: 1.0,
                      decimalPlaces: 0,
                    ),
                    _buildInputFieldTile(
                      title: 'Height',
                      controller: _heightController,
                      unit: 'meters (m)',
                      icon: Icons.height_rounded,
                      isDark: isDark,
                      primaryColor: primaryGreen,
                      minVal: 1.40,
                      maxVal: 2.00,
                      step: 0.01,
                      decimalPlaces: 2,
                    ),
                    _buildInputFieldTile(
                      title: 'Weight',
                      controller: _weightController,
                      unit: 'kg',
                      icon: Icons.scale_outlined,
                      isDark: isDark,
                      primaryColor: primaryGreen,
                      minVal: 40.0,
                      maxVal: 160.0,
                      step: 0.5,
                      decimalPlaces: 1,
                    ),
                    _buildInputFieldTile(
                      title: 'Water Intake',
                      controller: _waterController,
                      unit: 'Liters',
                      icon: Icons.water_drop_outlined,
                      isDark: isDark,
                      primaryColor: primaryGreen,
                      minVal: 1.0,
                      maxVal: 3.0,
                      step: 0.1,
                      decimalPlaces: 1,
                    ),
                    _buildInputFieldTile(
                      title: 'Physical Activity',
                      controller: _activityController,
                      unit: 'days/week',
                      icon: Icons.directions_run_rounded,
                      isDark: isDark,
                      primaryColor: primaryGreen,
                      minVal: 0.0,
                      maxVal: 3.0,
                      step: 0.1,
                      decimalPlaces: 1,
                    ),
                  ];

                  if (isWide) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: children.map((w) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: w)).toList(),
                    );
                  }

                  return Column(
                    children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
                  );
                },
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Dynamic Real-time BMI Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF4F7F4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed_rounded, color: primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Calculated BMI',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskResult.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: riskResult.color, width: 1.2),
                      ),
                      child: Text(
                        '${bmiValue.toStringAsFixed(1)} kg/m²',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: riskResult.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Result UI - Animated Circular Gauge
              Center(
                child: _buildCircularGauge(
                  riskResult: riskResult,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 20),

              // Category Label & Recommendation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskResult.color.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: riskResult.color.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: riskResult.color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          riskResult.label,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: riskResult.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      riskResult.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clinical Suggestion: ${riskResult.recommendation}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Clean "Recalculate & Reset" Button
              OutlinedButton.icon(
                onPressed: _resetInputs,
                icon: Icon(Icons.refresh_rounded, color: primaryGreen, size: 18),
                label: Text(
                  'Recalculate & Reset',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: activeColor, width: 1.2)
              : Border.all(color: Colors.transparent, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldTile({
    required String title,
    required TextEditingController controller,
    required String unit,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    required double minVal,
    required double maxVal,
    required double step,
    required int decimalPlaces,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($unit)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : const Color(0xFFF9FBF9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              // Decrement step button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: primaryColor),
                onPressed: () => _stepValue(controller, -step, minVal, maxVal, decimalPlaces),
              ),
              // Direct text input
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              // Increment step button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: primaryColor),
                onPressed: () => _stepValue(controller, step, minVal, maxVal, decimalPlaces),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularGauge({
    required ObesityRiskResult riskResult,
    required bool isDark,
  }) {
    final double targetPercent = riskResult.riskPercentage / 100.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetPercent),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        return CustomPaint(
          size: const Size(160, 160),
          painter: _CircularGaugePainter(
            progress: animatedVal,
            gaugeColor: riskResult.color,
            backgroundColor: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
          child: SizedBox(
            width: 160,
            height: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(animatedVal * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: riskResult.color,
                  ),
                ),
                Text(
                  'Risk Score',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter rendering a smooth gradient circular progress gauge.
class _CircularGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color gaugeColor;
  final Color backgroundColor;

  _CircularGaugePainter({
    required this.progress,
    required this.gaugeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 16) / 2;
    const strokeWidth = 12.0;

    // Track background
    final bgPaint = Paint()
      .. color = backgroundColor
      .. style = PaintingStyle.stroke
      .. strokeWidth = strokeWidth
      .. strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Active progress arc
    final progressPaint = Paint()
      .. color = gaugeColor
      .. style = PaintingStyle.stroke
      .. strokeWidth = strokeWidth
      .. strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // top of circle
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gaugeColor != gaugeColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
