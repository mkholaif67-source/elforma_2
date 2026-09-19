// Form Coach fallback for future, unmapped exercises.
//
// This is deliberately separate from the verified registry. It never mutates
// workout data, never promotes a result to a verified profile, and never emits
// form-correction rules. It uses only the exercise contract already on device
// (key/name/muscle); there is no network, LLM, or internet dependency.
//
// The fallback is a conservative bridge:
//   mechanics understood with two independent signals -> ROM/rep tracking
//   ambiguous or insufficient mechanics -> no Form Coach request (Cannot Assess)
//
// That is safer than manufacturing a rule from an exercise name.

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/form_profile.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/readiness.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';
import 'package:elforma/features/form_coach/profiles/form_profile_registry.dart';

enum FallbackMode { romAndReps, repsOnly, cannotAssess }

enum FallbackMovementFamily {
  press,
  fly,
  pull,
  row,
  curl,
  extension,
  squat,
  hinge,
  lunge,
  raise,
}

class FallbackMechanics {
  const FallbackMechanics({
    required this.family,
    required this.bodyRegion,
    required this.jointActions,
    required this.plane,
    required this.position,
    required this.equipment,
    required this.unilateral,
    required this.cameraView,
    required this.confidence,
  });

  final FallbackMovementFamily family;
  final String bodyRegion;
  final List<String> jointActions;
  final String plane;
  final String position;
  final String equipment;
  final bool unilateral;
  final PreferredView cameraView;
  final double confidence;
}

class FallbackResolution {
  const FallbackResolution({
    required this.mode,
    this.profile,
    this.mechanics,
    this.reasonAr = '',
  });

  final FallbackMode mode;
  final FormProfile? profile;
  final FallbackMechanics? mechanics;
  final String reasonAr;

  bool get isUsable => profile != null && mode != FallbackMode.cannotAssess;
}

class FormFallbackEngine {
  const FormFallbackEngine._();

  static FallbackResolution resolve({
    required String exerciseKey,
    required String exerciseName,
    required String muscle,
  }) {
    final String text = FormProfileRegistry.normalize(
      '$exerciseKey $exerciseName $muscle',
    );
    if (text.isEmpty) return _cannot('بيانات التمرين غير كافية');

    final _FamilyMatch? match = _family(text);
    if (match == null) return _cannot('الحركة غير واضحة بما يكفي');

    final String bodyRegion = _bodyRegion(text, muscle);
    final String equipment = _equipment(text);
    final String position = _position(text);
    final bool unilateral = _hasAny(text, <String>[
      'single',
      'one arm',
      'one leg',
      'unilateral',
      'alternating',
      'single arm',
      'single leg',
      'ذراع واحد',
      'رجل واحد',
    ]);

    // A family token alone is not sufficient. Require an independent clue from
    // muscle/region, equipment, or body position; this blocks name-only guesses.
    final bool secondaryEvidence =
        bodyRegion.isNotEmpty || equipment.isNotEmpty || position.isNotEmpty;
    if (!secondaryEvidence || match.ambiguous) {
      return _cannot('لا توجد معلومات كافية لتحديد ميكانيكا الحركة');
    }

    final double confidence =
        (match.score + (bodyRegion.isNotEmpty ? 0.12 : 0) +
                (equipment.isNotEmpty ? 0.08 : 0) +
                (position.isNotEmpty ? 0.05 : 0))
            .clamp(0.0, 0.96)
            .toDouble();
    if (confidence < 0.72) {
      return _cannot('ثقة ميكانيكا الحركة منخفضة');
    }

    final FallbackMechanics mechanics = FallbackMechanics(
      family: match.family,
      bodyRegion: bodyRegion.isEmpty ? _defaultRegion(match.family) : bodyRegion,
      jointActions: _jointActions(match.family),
      plane: _plane(match.family),
      position: position.isEmpty ? 'غير محدد' : position,
      equipment: equipment.isEmpty ? 'غير محدد' : equipment,
      unilateral: unilateral,
      cameraView: _view(match.family),
      confidence: confidence,
    );

    final FormProfile profile = _profileFor(
      exerciseName: exerciseName,
      mechanics: mechanics,
    );
    return FallbackResolution(
      mode: FallbackMode.romAndReps,
      profile: profile,
      mechanics: mechanics,
      reasonAr: 'تحليل احتياطي محافظ: متابعة المدى والعدات فقط',
    );
  }

  static FallbackResolution _cannot(String reason) => FallbackResolution(
        mode: FallbackMode.cannotAssess,
        reasonAr: reason,
      );

  static _FamilyMatch? _family(String text) {
    // Specific families must win before their broad parent (e.g. row before
    // pull, extension is split by body region later).
    const List<_FamilyMatch> candidates = <_FamilyMatch>[
      _FamilyMatch(FallbackMovementFamily.row, 0.74, <String>[
        'row',
        'rows',
        'remo',
        'رو',
        'سحب افقي',
      ]),
      _FamilyMatch(FallbackMovementFamily.fly, 0.74, <String>[
        'fly',
        'crossover',
        'pec deck',
        'فلاي',
        'كروس',
      ]),
      _FamilyMatch(FallbackMovementFamily.curl, 0.80, <String>[
        'curl',
        'كيرل',
        'بايسبس',
        'biceps',
      ]),
      _FamilyMatch(FallbackMovementFamily.extension, 0.72, <String>[
        'extension',
        'pushdown',
        'skull crusher',
        'تمديد',
        'ترايسبس',
      ]),
      _FamilyMatch(FallbackMovementFamily.lunge, 0.78, <String>[
        'lunge',
        'split squat',
        'step up',
        'step-up',
        'اندفاع',
      ]),
      _FamilyMatch(FallbackMovementFamily.hinge, 0.80, <String>[
        'deadlift',
        'rdl',
        'romanian',
        'stiff leg',
        'hip thrust',
        'good morning',
        'سحب روماني',
      ]),
      _FamilyMatch(FallbackMovementFamily.squat, 0.78, <String>[
        'squat',
        'leg press',
        'hack',
        'pendulum',
        'سكوات',
      ]),
      _FamilyMatch(FallbackMovementFamily.raise, 0.76, <String>[
        'raise',
        'shrug',
        'y raise',
        'face pull',
        'رفعة',
        'ترابيس',
      ]),
      _FamilyMatch(FallbackMovementFamily.pull, 0.72, <String>[
        'pulldown',
        'pull down',
        'pull-up',
        'pull up',
        'chin up',
        'pullover',
        'سحب',
      ]),
      _FamilyMatch(FallbackMovementFamily.press, 0.73, <String>[
        'press',
        'push up',
        'push-up',
        'dip',
        'ضغط',
      ]),
    ];

    _FamilyMatch? best;
    for (final _FamilyMatch candidate in candidates) {
      if (!_hasAny(text, candidate.tokens)) continue;
      final bool ambiguous = candidate.family == FallbackMovementFamily.extension &&
          !_hasAny(text, <String>[
            'tricep',
            'triceps',
            'leg extension',
            'knee',
            'تمديد الرجل',
            'ترايسبس',
          ]);
      if (best == null || candidate.score > best.score) {
        best = _FamilyMatch(candidate.family, candidate.score, candidate.tokens,
            ambiguous: ambiguous);
      }
    }
    return best;
  }

  static String _bodyRegion(String text, String muscle) {
    final String value = FormProfileRegistry.normalize('$text $muscle');
    if (_hasAny(value, <String>[
      'chest',
      'pec',
      'pector',
      'shoulder',
      'delt',
      'lat',
      'back',
      'trap',
      'tricep',
      'bicep',
      'arm',
      'صدر',
      'كتف',
      'ظهر',
      'ذراع',
    ])) return 'upper body';
    if (_hasAny(value, <String>[
      'quad',
      'hamstring',
      'glute',
      'leg',
      'calf',
      'hip',
      'رجل',
      'فخذ',
      'سمانة',
      'مؤخرة',
    ])) return 'lower body';
    if (_hasAny(value, <String>['core', 'ab', 'abs', 'بطن'])) return 'trunk';
    return '';
  }

  static String _equipment(String text) {
    for (final String token in <String>[
      'cable',
      'machine',
      'smith',
      'barbell',
      'dumbbell',
      'band',
      'kettlebell',
      'كابل',
      'جهاز',
      'بار',
      'دامبل',
    ]) {
      if (text.contains(token)) return token;
    }
    return '';
  }

  static String _position(String text) {
    for (final String token in <String>[
      'seated',
      'standing',
      'lying',
      'incline',
      'decline',
      'bent over',
      'chest supported',
      'front',
      'side',
      'جالس',
      'واقف',
      'مائل',
    ]) {
      if (text.contains(token)) return token;
    }
    return '';
  }

  static String _defaultRegion(FallbackMovementFamily family) {
    switch (family) {
      case FallbackMovementFamily.squat:
      case FallbackMovementFamily.hinge:
      case FallbackMovementFamily.lunge:
        return 'lower body';
      case FallbackMovementFamily.curl:
      case FallbackMovementFamily.extension:
      case FallbackMovementFamily.press:
      case FallbackMovementFamily.fly:
      case FallbackMovementFamily.pull:
      case FallbackMovementFamily.row:
      case FallbackMovementFamily.raise:
        return 'upper body';
    }
  }

  static List<String> _jointActions(FallbackMovementFamily family) {
    switch (family) {
      case FallbackMovementFamily.press:
      case FallbackMovementFamily.fly:
        return const <String>['shoulder horizontal flexion/adduction', 'elbow extension/flexion'];
      case FallbackMovementFamily.pull:
      case FallbackMovementFamily.row:
        return const <String>['shoulder extension/adduction', 'elbow flexion'];
      case FallbackMovementFamily.curl:
        return const <String>['elbow flexion/extension'];
      case FallbackMovementFamily.extension:
        return const <String>['elbow or knee extension/flexion'];
      case FallbackMovementFamily.squat:
      case FallbackMovementFamily.lunge:
        return const <String>['hip and knee flexion/extension', 'ankle dorsiflexion'];
      case FallbackMovementFamily.hinge:
        return const <String>['hip flexion/extension', 'trunk angle change'];
      case FallbackMovementFamily.raise:
        return const <String>['shoulder elevation/abduction'];
    }
  }

  static String _plane(FallbackMovementFamily family) {
    switch (family) {
      case FallbackMovementFamily.press:
      case FallbackMovementFamily.fly:
      case FallbackMovementFamily.pull:
      case FallbackMovementFamily.row:
        return 'transverse/scapular';
      case FallbackMovementFamily.curl:
      case FallbackMovementFamily.extension:
      case FallbackMovementFamily.raise:
        return 'sagittal or frontal';
      case FallbackMovementFamily.squat:
      case FallbackMovementFamily.hinge:
      case FallbackMovementFamily.lunge:
        return 'sagittal';
    }
  }

  static PreferredView _view(FallbackMovementFamily family) {
    switch (family) {
      case FallbackMovementFamily.squat:
      case FallbackMovementFamily.hinge:
      case FallbackMovementFamily.lunge:
      case FallbackMovementFamily.curl:
      case FallbackMovementFamily.extension:
        return PreferredView.side;
      case FallbackMovementFamily.raise:
      case FallbackMovementFamily.press:
      case FallbackMovementFamily.fly:
      case FallbackMovementFamily.pull:
      case FallbackMovementFamily.row:
        return PreferredView.front;
    }
  }

  static FormProfile _profileFor({
    required String exerciseName,
    required FallbackMechanics mechanics,
  }) {
    final bool lower = mechanics.bodyRegion == 'lower body';
    final bool raise = mechanics.family == FallbackMovementFamily.raise;
    final bool extensionIsLeg =
        mechanics.family == FallbackMovementFamily.extension && lower;
    final bool hinge = mechanics.family == FallbackMovementFamily.hinge;
    final List<FcJoint> joints = hinge ? const <FcJoint>[FcJoint.shoulder, FcJoint.hip, FcJoint.knee]
        : lower || extensionIsLeg
        ? const <FcJoint>[FcJoint.hip, FcJoint.knee, FcJoint.ankle]
        : const <FcJoint>[FcJoint.shoulder, FcJoint.elbow, FcJoint.wrist];
    final String metricId = raise ? 'abduction' : 'fallback_angle';
    final MetricSpec metric = raise
        ? MetricSpec(
            id: 'abduction',
            kind: MetricKind.limbAbductionFromTorso,
            joints: <FcJoint>[FcJoint.shoulder, FcJoint.elbow],
            side: mechanics.unilateral ? MetricSide.activeSide : MetricSide.mean,
            labelAr: 'ارتفاع الذراع',
          )
        : MetricSpec(
            id: 'fallback_angle',
            kind: MetricKind.jointAngle,
            joints: joints,
            side: mechanics.unilateral ? MetricSide.activeSide : MetricSide.mean,
            labelAr: 'زاوية الحركة',
          );

    double top = 165;
    double bottom = 80;
    if (raise) {
      top = 14;
      bottom = 82;
    } else if (mechanics.family == FallbackMovementFamily.hinge) {
      top = 168;
      bottom = 100;
    } else if (mechanics.family == FallbackMovementFamily.squat ||
        mechanics.family == FallbackMovementFamily.lunge) {
      top = 168;
      bottom = 90;
    }

    final FormProfileVariant variant = FormProfileVariant(
      id: 'fallback.${mechanics.family.name}',
      titleAr: 'متابعة حركة — $exerciseName',
      supportLevel: FormSupportLevel.trackingOnly,
      readiness: ReadinessSpec(
        requiredJoints: raise ? const [FcJoint.shoulder, FcJoint.elbow, FcJoint.hip] : joints,
        // Front-view bilateral work needs both sides; side-view work can use
        // the visible side even when the exercise itself is bilateral.
        requireBothSides: mechanics.cameraView == PreferredView.front &&
            !mechanics.unilateral,
        view: mechanics.cameraView,
        minTorsoFraction: 0.08,
        maxTorsoFraction: 0.78,
      ),
      metrics: <MetricSpec>[metric],
      repCycle: RepCycleSpec(
        driverMetricId: metricId,
        topValue: top,
        bottomValue: bottom,
        enterMargin: 18,
        minAmplitude: mechanics.family == FallbackMovementFamily.fly ? 28 : 42,
        partialAmplitude: mechanics.family == FallbackMovementFamily.fly ? 16 : 24,
        topLabelAr: 'بداية الحركة',
        bottomLabelAr: 'نهاية الحركة',
      ),
      // No fallback form rules: a generic camera proxy must never say that a
      // joint, bar path, grip, load, or spine position is incorrect.
      rules: const <FormRule>[],
      driverMinConfidence: 0.58,
    );
    return FormProfile(
      id: 'fallback.${mechanics.family.name}',
      titleAr: 'متابعة حركة — $exerciseName',
      supportLevel: FormSupportLevel.trackingOnly,
      setupHintAr: 'ثبّت الهاتف من ${mechanics.cameraView == PreferredView.side ? 'الجانب' : 'الأمام'} وأظهر المفاصل المطلوبة',
      detectableAr: const <String>['العدات التقريبية', 'مرحلة الحركة', 'المدى الظاهر'],
      notDetectableAr: const <String>[
        'الوزن والقبضة ومسار الأداة',
        'التفاصيل التي تحجبها الآلة أو زاوية التصوير',
        'الحكم على الخطأ الفني بدون Profile موثوق',
      ],
      matchKeywords: const <String>[],
      variants: <FormProfileVariant>[variant],
      completion: const CompletionSpec(fallbackTargetReps: 10),
    );
  }
}

class _FamilyMatch {
  const _FamilyMatch(
    this.family,
    this.score,
    this.tokens, {
    this.ambiguous = false,
  });

  final FallbackMovementFamily family;
  final double score;
  final List<String> tokens;
  final bool ambiguous;
}

bool _hasAny(String text, List<String> tokens) =>
    tokens.any((String token) => text.contains(token));
