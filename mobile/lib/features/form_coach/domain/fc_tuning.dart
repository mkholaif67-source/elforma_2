// Form Coach - every tunable number in one place.
//
// These are engineering defaults, NOT scientific constants, and they were not
// calibrated on recorded users. They are meant to be tuned on real devices with
// the built-in debug panel and the replay harness in tools/form_coach_calibration.

class FcTuning {
  const FcTuning._();

  // --- landmark quality
  static const double landmarkMinVisibility = 0.45;
  static const double landmarkHardFloor = 0.15;
  static const double ruleMinConfidence = 0.6;

  // --- smoothing (One Euro filter)
  static const double smoothMinCutoff = 1.1;
  static const double smoothBeta = 0.09;
  static const double smoothDerivativeCutoff = 1.0;
  static const double visibilitySmoothingAlpha = 0.45;

  // --- performance
  static const int targetAnalysisFps = 15;
  static const int minFrameIntervalMs = 1000 ~/ targetAnalysisFps;
  static const double slowInferenceMs = 90;
  static const int maxFrameIntervalMs = 200;
  static const double minUsableFps = 7;

  // --- tracking continuity
  static const int poseLostGraceMs = 500;
  static const int returnToSetupAfterMs = 3500;
  static const int repAbortGapMs = 700;
  static const int liveWarmupMs = 1200;
  static const int unknownMovementAfterMs = 6000;

  // --- scene / subject stability
  static const double subjectScaleJumpRatio = 0.35;
  static const double subjectShiftInTorso = 0.55;
  static const int subjectSettleMs = 900;

  // --- ready check
  static const int readyStableMs = 900;
  static const double readyFrameMargin = 0.02;
  static const double lowLightMeanLuma = 45;
  static const double frontViewMinSpread = 0.45;
  static const double sideViewMaxSpread = 0.34;

  // --- feedback (anti-nagging)
  static const int globalCueCooldownMs = 3200;
  static const int defaultMaxFiresPerSet = 3;
  static const int defaultRuleCooldownMs = 6000;
  static const double defaultMinConsistency = 0.7;
  static const int violationStreakGapMs = 150;

  // --- tempo
  static const int hardMinRepMs = 550;
  static const int fastRepsBeforeCue = 2;
  static const double tempoFastRatio = 0.55;
}
