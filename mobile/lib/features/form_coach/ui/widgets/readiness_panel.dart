// Form Coach - setup / ready check panel.
//
// Shows ONE instruction at a time (the highest-priority issue) plus a progress
// bar of how long the position has been stable. No judging happens while this
// panel is visible.

import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:flutter/material.dart';

class ReadinessPanel extends StatelessWidget {
  const ReadinessPanel({
    super.key,
    required this.report,
    required this.setupHintAr,
    this.detailed = false,
  });

  final ReadinessReport report;
  final String setupHintAr;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final String cue = report.unknown ? 'بدوّر عليك في الكادر...' : report.cueAr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            cue,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (setupHintAr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              setupHintAr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: report.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB4D565)),
            ),
          ),
          if (detailed) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'view=${report.detectedView.name}  torso=${report.torsoFraction.toStringAsFixed(2)}  '
              'spread=${report.spreadRatio.toStringAsFixed(2)}  vis=${report.meanVisibility.toStringAsFixed(2)}\n'
              'issues=${report.issues.map((ReadinessIssue i) => i.name).join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
