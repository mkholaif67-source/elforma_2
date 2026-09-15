// Form Coach - cue banner.
//
// Visual twin of the audio cue. It appears only when the engine actually fires a
// cue and fades out by itself, so the live screen stays quiet when the form is
// fine.

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:flutter/material.dart';

class CueBanner extends StatefulWidget {
  const CueBanner({super.key, required this.cue, this.showDetail = true});

  final FormCue? cue;
  final bool showDetail;

  @override
  State<CueBanner> createState() => _CueBannerState();
}

class _CueBannerState extends State<CueBanner> {
  String? _shownId;
  bool _visible = false;

  @override
  void didUpdateWidget(CueBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final FormCue? cue = widget.cue;
    if (cue == null) return;
    final String id = '${cue.id}-${cue.tMs}';
    if (id == _shownId) return;
    _shownId = id;
    setState(() => _visible = true);
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted || _shownId != id) return;
      setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final FormCue? cue = widget.cue;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _visible && cue != null ? 1 : 0,
      child: cue == null
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _background(cue),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    cue.textAr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.showDetail && cue.detailAr.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      cue.detailAr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Color _background(FormCue cue) {
    if (cue.kind == FormCueKind.setFinished) {
      return const Color(0xFF24633D).withValues(alpha: 0.94);
    }
    if (cue.severity == RuleSeverity.critical) {
      return const Color(0xFFB4441F).withValues(alpha: 0.94);
    }
    return const Color(0xFF9A5C16).withValues(alpha: 0.94);
  }
}
