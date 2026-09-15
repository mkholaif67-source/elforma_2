// Form Coach - audio feedback.
//
// Silence is the normal state. When the engine decides to speak we play a short
// alert sound + haptic first (it survives noisy gyms and headphones) and then a
// very short Arabic voice cue. If no Arabic TTS voice exists on the device we
// keep the alert and drop the speech instead of switching to another language.

import 'package:elforma/features/form_coach/domain/assessment.dart';
import 'package:elforma/features/form_coach/domain/form_rule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FormCuePlayer {
  FormCuePlayer();

  final FlutterTts _tts = FlutterTts();
  bool _voiceAvailable = false;
  bool _disposed = false;
  bool _muted = false;

  bool get voiceAvailable => _voiceAvailable;
  bool get muted => _muted;

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) {
      await _stopSpeech();
    }
  }

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final dynamic egyptian = await _tts.isLanguageAvailable('ar-EG');
      final dynamic arabic = await _tts.isLanguageAvailable('ar');
      if (egyptian == true) {
        await _tts.setLanguage('ar-EG');
        _voiceAvailable = true;
      } else if (arabic == true) {
        await _tts.setLanguage('ar');
        _voiceAvailable = true;
      }
      if (_voiceAvailable) {
        await _tts.setSpeechRate(0.52);
        await _tts.setVolume(1);
        await _tts.setPitch(1);
      }
    } catch (_) {
      // TTS engine missing or misconfigured: we still beep.
      _voiceAvailable = false;
    }
  }

  Future<void> play(FormCue cue) async {
    if (_disposed || _muted) return;
    final bool strong = cue.kind == FormCueKind.setFinished ||
        cue.severity == RuleSeverity.critical;
    await alert(strong: strong);
    if (cue.kind == FormCueKind.setFinished) {
      // Double beep marks the end of the set even without a voice.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await alert(strong: true);
    }
    await speak(cue.textAr);
  }

  Future<void> alert({bool strong = false}) async {
    if (_disposed || _muted) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
      if (strong) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Sound/haptics are best-effort.
    }
  }

  Future<void> speak(String text) async {
    if (_disposed || _muted || !_voiceAvailable || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Never let feedback break the session.
    }
  }

  Future<void> _stopSpeech() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopSpeech();
  }
}
