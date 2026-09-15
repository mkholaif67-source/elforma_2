// Form Coach - the camera screen.
//
// Lifecycle contract: this route owns the camera, the engine and the audio cue
// player, and disposes all three on pop. The training session screen underneath
// keeps its own state and is never rebuilt or mutated by this screen.
//
// Nothing here is persisted: reps counted on this screen are runtime-only.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/integration/form_coach_request.dart';
import 'package:elforma/features/form_coach/runtime/camera_pose_pipeline.dart';
import 'package:elforma/features/form_coach/runtime/form_coach_controller.dart';
import 'package:elforma/features/form_coach/ui/widgets/cue_banner.dart';
import 'package:elforma/features/form_coach/ui/widgets/debug_panel.dart';
import 'package:elforma/features/form_coach/ui/widgets/pose_overlay.dart';
import 'package:elforma/features/form_coach/ui/widgets/readiness_panel.dart';
import 'package:elforma/theme.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FormCoachScreen extends StatefulWidget {
  const FormCoachScreen({super.key, required this.request});

  final FormCoachRequest request;

  @override
  State<FormCoachScreen> createState() => _FormCoachScreenState();
}

class _FormCoachScreenState extends State<FormCoachScreen>
    with WidgetsBindingObserver {
  late final FormCoachController _controller;
  bool _wakelockWasOn = true;

  @override
  void initState() {
    super.initState();
    _controller = FormCoachController(request: widget.request);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller.start());
    });
    unawaited(_enableWakelock());
  }

  Future<void> _enableWakelock() async {
    try {
      _wakelockWasOn = await WakelockPlus.enabled;
      if (!_wakelockWasOn) await WakelockPlus.enable();
    } catch (_) {
      // Best effort only.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_controller.handleLifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    if (!_wakelockWasOn) {
      unawaited(WakelockPlus.disable().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final String? error = _controller.errorTextAr;
          if (error != null) return _ErrorView(message: error, failure: _controller.failure);

          final FormCoachSnapshot? snapshot = _controller.snapshot;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _preview(),
              if (snapshot != null) _overlay(snapshot),
              _gradient(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _header(snapshot),
                    Expanded(child: _body(snapshot)),
                    if (_controller.debugEnabled && snapshot != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: DebugPanel(
                          snapshot: snapshot,
                          variantId: snapshot.activeVariantId ?? '-',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _preview() {
    final CameraController? camera = _controller.cameraController;
    if (camera == null || !camera.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white24),
          ),
        ),
      );
    }
    final Size? size = camera.value.previewSize;
    final double width = size?.height ?? 720;
    final double height = size?.width ?? 1280;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(camera),
        ),
      ),
    );
  }

  Widget _overlay(FormCoachSnapshot snapshot) {
    final CameraController? camera = _controller.cameraController;
    final Size? size = camera?.value.previewSize;
    final double aspect =
        size == null || size.width == 0 ? 0.5625 : size.height / size.width;
    return PoseOverlay(
      sample: snapshot.pose,
      imageAspect: aspect,
      mirror: _controller.isMirrored,
      verdict: snapshot.verdict,
      showConfidence: _controller.debugEnabled,
    );
  }

  Widget _gradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const <double>[0, 0.45, 1],
          ),
        ),
      ),
    );
  }

  Widget _header(FormCoachSnapshot? snapshot) {
    final FormProfile profile = widget.request.profile;
    final String setLabel = widget.request.session.setLabelAr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'خروج',
          ),
          Expanded(
            child: GestureDetector(
              // Hidden developer calibration switch.
              onLongPress: () => unawaited(_controller.toggleDebug()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.request.session.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    <String>[
                      'تابع أداءك',
                      formSupportLevelAr(profile.supportLevel),
                      if (setLabel.isNotEmpty) setLabel,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_controller.toggleMuted()),
            icon: Icon(
              _controller.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
            tooltip: _controller.muted ? 'تشغيل الصوت' : 'كتم الصوت',
          ),
        ],
      ),
    );
  }

  Widget _body(FormCoachSnapshot? snapshot) {
    if (snapshot == null) {
      return const Center(
        child: Text(
          'بفتح الكاميرا...',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      );
    }

    switch (snapshot.stage) {
      case FormCoachStage.starting:
      case FormCoachStage.readyCheck:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ReadinessPanel(
                report: snapshot.readiness,
                setupHintAr: widget.request.profile.setupHintAr,
                detailed: _controller.debugEnabled,
              ),
            ],
          ),
        );
      case FormCoachStage.countdown:
        final int seconds = (snapshot.countdownRemainingMs / 1000).ceil();
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                seconds <= 0 ? 'يلا' : '$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                snapshot.statusTextAr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      case FormCoachStage.live:
        return _liveBody(snapshot);
      case FormCoachStage.finished:
        return _finishedBody(snapshot);
    }
  }

  Widget _liveBody(FormCoachSnapshot snapshot) {
    final bool durationMode = snapshot.targetSeconds != null;
    final String counter = durationMode
        ? '${(snapshot.heldMs / 1000).floor()}'
        : '${snapshot.reps}';
    final String counterHint = durationMode
        ? (snapshot.targetSeconds == null ? 'ثانية' : 'من ${snapshot.targetSeconds} ثانية')
        : (snapshot.targetReps == null ? 'عدة' : 'من ${snapshot.targetReps} عدة');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: CueBanner(cue: snapshot.cue ?? snapshot.lastCue),
          ),
          const Spacer(),
          if (snapshot.verdict == FormVerdict.cannotAssess)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                snapshot.statusTextAr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  counter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    counterHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (snapshot.partialReps > 0)
            Text(
              'عدات ناقصة: ${snapshot.partialReps}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _finishedBody(FormCoachSnapshot snapshot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                const Icon(Icons.check_circle_rounded, color: AppColors.wo, size: 38),
                const SizedBox(height: 8),
                Text(
                  snapshot.statusTextAr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.partialReps > 0
                      ? 'عدات كاملة: ${snapshot.reps} · ناقصة: ${snapshot.partialReps}'
                      : 'عدات كاملة: ${snapshot.reps}',
                  style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'العد ده للمتابعة فقط ومابيتسجّلش في تقدمك — سجل المجموعة من صفحة التمرين زي ما إنت عامل',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => unawaited(_controller.restartSet()),
                        child: const Text('مجموعة تانية'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('خلاص'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.failure});

  final String message;
  final CameraFailure? failure;

  @override
  Widget build(BuildContext context) {
    final bool permission = failure == CameraFailure.permissionDenied;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              permission ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
              color: Colors.white70,
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
            if (permission) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'افتح إعدادات الهاتف ٔ التطبيقات ٔ الفورمة ٔ الأذونات وفعّل الكاميرا، وبقية التمرين شغالة عادي بدونها',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('رجوع للتمرين'),
            ),
          ],
        ),
      ),
    );
  }
}
