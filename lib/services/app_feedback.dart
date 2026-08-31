import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../data/progress_store.dart';

/// Centralizes haptic + sound feedback so every interactive moment reacts
/// consistently, gated behind the user's sound preference in one place
/// instead of scattering `if (soundEnabled)` checks across every screen.
/// Every call is fire-and-forget — a missed sound or haptic is never worth
/// blocking (or failing a test over) the tap that triggered it.
class AppFeedback {
  AppFeedback._();

  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static bool get _soundOn => ProgressStore.instance.soundEnabled;

  /// A plain navigation/selection tap — buttons, nav items, cards.
  static void tap() {
    HapticFeedback.selectionClick();
    if (_soundOn) _play('tap.wav');
  }

  /// Haptic only, no sound — the flashcard screen's flip/rate/close taps.
  /// Flashcards are meant to feel quiet and read-focused, not chime on
  /// every single flip; the sounds are reserved for the quiz, where a
  /// right/wrong signal actually carries information.
  static void tapSilent() {
    HapticFeedback.selectionClick();
  }

  /// A correct quiz/pair/expert answer.
  static void correct() {
    HapticFeedback.lightImpact();
    if (_soundOn) _play('correct.wav');
  }

  /// A wrong quiz/pair/expert answer — a softer haptic than [correct], not
  /// a punishing one.
  static void incorrect() {
    HapticFeedback.lightImpact();
    if (_soundOn) _play('incorrect.wav');
  }

  /// A lesson/expert-challenge completion moment.
  static void celebrate() {
    HapticFeedback.mediumImpact();
    if (_soundOn) _play('complete.wav');
  }

  static void _play(String fileName) {
    try {
      // ignore: discarded_futures
      _player.play(AssetSource('sounds/$fileName')).catchError((_) {});
    } catch (_) {
      // No audio platform available (e.g. widget tests) — feedback is
      // best-effort, never a reason to break the interaction it decorates.
    }
  }
}
