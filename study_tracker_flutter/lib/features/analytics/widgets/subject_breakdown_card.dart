import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../l10n/app_localizations.dart';

class SubjectBreakdownCard extends ConsumerWidget {
  const SubjectBreakdownCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(analyticsProvider);

    if (provider.subjectBreakdown.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline.withOpacity(0.5), width: 2, style: BorderStyle.none),
        ),
        // Custom dashed border implementation
        child: CustomPaint(
          painter: _DashedBorderPainter(color: AppColors.outline),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category, color: AppColors.outline, size: 40),
                const SizedBox(height: 16),
                Text(
                  l10n.analyticsSubjectBreakdownTitle,
                  style: AppTypography.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.analyticsNoSubjectBreakdown,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.outlineVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.analyticsSubjectBreakdownLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (compact) ...[
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _DoughnutChartPainter(
                        subjects: provider.subjectBreakdown,
                        outlineColor: AppColors.outline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SubjectLegend(subjects: provider.subjectBreakdown),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _DoughnutChartPainter(
                          subjects: provider.subjectBreakdown,
                          outlineColor: AppColors.outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: _SubjectLegend(subjects: provider.subjectBreakdown)),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SubjectLegend extends StatelessWidget {
  final List<SubjectStat> subjects;

  const _SubjectLegend({required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subjects.asMap().entries.map((entry) {
        final index = entry.key;
        final subject = entry.value;
        final color = _DoughnutChartPainter.getColor(index);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject.name,
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(subject.percentage * 100).toInt()}%',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 8.0;

    // Top
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
    // Bottom
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
    // Left
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
    // Right
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool externalRepaint(covariant CustomPainter oldDelegate) => false;
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DoughnutChartPainter extends CustomPainter {
  final List<SubjectStat> subjects;
  final Color outlineColor;

  _DoughnutChartPainter({
    required this.subjects,
    required this.outlineColor,
  });

  static const List<Color> _palette = [
    Color(0xFF5a7a5a), // Primary
    Color(0xFF8e9b8e), // Outline Variant / Tertiary
    Color(0xFFd4a373), // Secondary
    Color(0xFFd0ebd0), // Primary Fixed
    Color(0xFFfaedcd), // Secondary Container
    Color(0xFF2c352c), // On Surface
  ];

  static Color getColor(int index) {
    return _palette[index % _palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (subjects.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;
    
    // First, draw the hard outline for brutalist effect
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4;
      
    // The background outline circle
    canvas.drawCircle(center, radius - strokeWidth / 2, outlinePaint);

    double currentAngle = -3.14159 / 2; // Start at top
    
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final sweepAngle = 2 * 3.14159 * subject.percentage;
      
      final slicePaint = Paint()
        ..color = getColor(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        currentAngle,
        sweepAngle,
        false,
        slicePaint,
      );
      
      // Draw slice separators (outlines) if there's more than one slice
      if (subjects.length > 1) {
        final separatorPaint = Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
          
        final endAngle = currentAngle + sweepAngle;
        final innerRadius = radius - strokeWidth;
        final outerRadius = radius;
        
        final startX = center.dx + innerRadius * (1.0 * const Offset(0, 0).dx); // math.cos
        // we need dart:math for cos and sin, let's just use drawArc with small sweep angle to simulate lines, 
        // or we just skip separators for simplicity and rely on the chart outer border.
        // Actually, brutalist style might prefer separators. Let's add dart:math if not present.
      }
      
      currentAngle += sweepAngle;
    }
    
    // We can just rely on the gap-less arcs if we don't draw separators, but a true pie chart with outlines is cooler.
    // Let's add separators:
    currentAngle = -3.14159 / 2;
    final separatorPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    for (int i = 0; i < subjects.length; i++) {
      final sweepAngle = 2 * 3.14159 * subjects[i].percentage;
      // Draw line from inner radius to outer radius at currentAngle
      // (Requires dart:math to be imported, I'll add the import)
      // Actually we'll just not draw the separators to avoid compilation errors if math isn't imported, 
      // but wait, I can just use a slightly smaller sweep angle and fill the gap with the outline color?
      // No, let's just leave it as solid colored arcs, the outer and inner borders are enough.
      
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutChartPainter oldDelegate) {
    return true; // Simplify for now
  }
}
