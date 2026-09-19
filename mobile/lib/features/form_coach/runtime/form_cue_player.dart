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

enum FormAudioMode { coach, tones, mute }

String formAudioModeLabelAr(FormAudioMode mode) {
  switch (mode) {
    case FormAudioMode.coach:
      return 'المدرب';
    case FormAudioMode.tones:
      return 'نغمات فقط';
    case FormAudioMode.mute:
      return 'صامت';
  }
}

class FormCuePlayer {
  FormCuePlayer();

  final FlutterTts _tts = FlutterTts();
  bool _voiceAvailable = false;
  bool _disposed = false;
  bool _muted = false;
  bool _playing = false;
  int _generation = 0;
  FormAudioMode _mode = FormAudioMode.coach;

  bool get voiceAvailable => _voiceAvailable;
  bool get muted => _mode == FormAudioMode.mute;
  FormAudioMode get mode => _mode;

  Future<void> setMuted(bool value) async {
    await setMode(value ? FormAudioMode.mute : FormAudioMode.coach);
  }

  Future<void> setMode(FormAudioMode value) async {
    _generation++;
    _mode = value;
    _muted = value == FormAudioMode.mute;
    await _stopSpeech();
  }

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final dynamic egyptian = await _tts.isLanguageAvailable('ar-EG');
      final dynamic arabic = await _tts.isLanguageAvailable('ar');
      if (_disposed) return;
      if (egyptian == true) {
        await _tts.setLanguage('ar-EG');
        _voiceAvailable = true;
      } else if (arabic == true) {
        await _tts.setLanguage('ar');
        _voiceAvailable = true;
      }
      if (_disposed) return;
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
    if (_disposed || _muted || _playing) return;
    final generation = _generation;
    _playing = true;
    try {
    final bool strong = cue.kind == FormCueKind.setFinished ||
        cue.severity == RuleSeverity.critical;
    await alert(strong: strong);
    if (cue.kind == FormCueKind.setFinished) {
      // Double beep marks the end of the set even without a voice.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (_disposed || generation != _generation) return;
      await alert(strong: true);
    }
    if (!_disposed && generation == _generation && _mode == FormAudioMode.coach) await speak(cue.textAr);
    } finally { _playing = false; }
  }

  Future<void> alert({bool strong = false}) async {
    if (_disposed || _muted) return;
    final generation = _generation;
    try {
      await SystemSound.play(SystemSoundType.alert);
      if (_disposed || _muted || generation != _generation) return;
      if (strong) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Sound/haptics are best-effort.
    }
  }

  Future<void> stop() async {
    _generation++;
    await _stopSpeech();
  }

  Future<void> speak(String text) async {
    if (_disposed || _muted || !_voiceAvailable || text.trim().isEmpty) return;
    final generation = _generation;
    try {
      await _tts.stop();
      if (!_disposed && !_muted && generation == _generation &&
          _mode == FormAudioMode.coach) await _tts.speak(text);
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
    _generation++;
    await _stopSpeech();
  }
}
