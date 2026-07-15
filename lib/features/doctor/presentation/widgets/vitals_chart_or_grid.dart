import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../patient/models/vital.dart';
import 'vitals_chart_painter.dart';

class VitalsChartOrGrid extends StatelessWidget {
  final List<Vital> vitals;

  const VitalsChartOrGrid({super.key, required this.vitals});

  Widget _buildEmptyCard(BuildContext context, String message) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.textSecondary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (vitals.isEmpty) return _buildEmptyCard(context, 'No vitals recorded');

    // Group vitals by type
    final grouped = <String, List<Vital>>{};
    for (var v in vitals) {
      grouped.putIfAbsent(v.type, () => []).add(v);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              grouped.entries.map((entry) {
                final type = entry.key;
                final list = entry.value.reversed.toList();
                final latest = entry.value.first;

                // Parse values
                final values = <double>[];
                final secondaryValues = <double>[];

                for (var v in list) {
                  if (type == 'blood_pressure') {
                    final parts = v.value.split('/');
                    final sys = double.tryParse(parts[0]) ?? 120.0;
                    final dia =
                        parts.length > 1
                            ? (double.tryParse(parts[1]) ?? 80.0)
                            : 80.0;
                    values.add(sys);
                    secondaryValues.add(dia);
                  } else {
                    final val = double.tryParse(v.value) ?? 0.0;
                    values.add(val);
                  }
                }

                final chartColor = t.accent;
                final title = type.replaceAll('_', ' ').toUpperCase();

                return SizedBox(
                  width: itemWidth,
                  height: 112,
                  child: SquircleCard(
                    radius: AppSpacing.squircleGrouped,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: t.textSecondary.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          latest.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: t.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        latest.unit,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: t.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: t.tint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${list.length} Log${list.length > 1 ? "s" : ""}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: t.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (list.length > 1)
                          SizedBox(
                            height: 36,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: VitalsChartPainter(
                                values: values,
                                secondaryValues:
                                    type == 'blood_pressure'
                                        ? secondaryValues
                                        : null,
                                color: chartColor,
                                secondaryColor:
                                    type == 'blood_pressure'
                                        ? chartColor.withValues(alpha: 0.45)
                                        : null,
                                ringColor: t.card,
                              ),
                            ),
                          )
                        else ...[
                          const Spacer(),
                          Text(
                            'Recorded:\n${DateFormat('dd MMM yyyy, h:mm a').format(latest.createdAt ?? DateTime.now())}',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}
