// lib/services/haptic_service.dart

import 'package:flutter/services.dart';

class HapticService {
  HapticService._(); // private constructor — no instantiation needed

  // ─────────────────────────────────────────────────────────────────────────────
  // BASIC LEVELS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Very soft tap — chip tap, icon press, small UI element
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Normal press feel — button tap, play/pause, toggle, expand
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Strong punch feel — delete, error, destructive action
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Tick feel — slider movement, reorder drag, tab switch, preset tap
  static Future<void> selection() => HapticFeedback.selectionClick();

  // ─────────────────────────────────────────────────────────────────────────────
  // SEMANTIC PATTERNS  (combinations of basic levels)
  // ─────────────────────────────────────────────────────────────────────────────

  /// ✅ Success  →  soft → medium  (positive double pulse)
  /// USE: merge complete, export done, file saved, project created
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// ❌ Error  →  heavy → heavy  (hard double punch)
  /// USE: merge failed, permission denied, invalid action
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// ⚠️ Warning  →  medium → light  (descending)
  /// USE: file missing, trim overlaps, caution dialog
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  /// 🎉 Celebration  →  light → medium → heavy  (ascending triple)
  /// USE: merge complete with all songs, big milestone
  static Future<void> celebrate() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// 👆 Long press detected
  /// USE: rename song, show context menu, hold to reorder
  static Future<void> longPress() => HapticFeedback.mediumImpact();

  /// 👆👆 Double tap
  /// USE: double tap to play, double tap to reset
  static Future<void> doubleTap() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // APP-SPECIFIC ACTIONS
  // ─────────────────────────────────────────────────────────────────────────────

  /// ▶ Play song tapped
  static Future<void> play() => HapticFeedback.lightImpact();

  /// ⏸ Pause tapped
  static Future<void> pause() => HapticFeedback.lightImpact();

  /// ⏹ Stop tapped
  static Future<void> stop() => HapticFeedback.mediumImpact();

  /// ⏩ Seek / scrub in player
  static Future<void> seek() => HapticFeedback.selectionClick();

  /// ⏪⏩ Skip 10s button
  static Future<void> skip() => HapticFeedback.lightImpact();

  /// ✂️ Trim applied (Apply Trim button)
  static Future<void> trimApplied() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// 🎵 Song added to project
  static Future<void> songAdded() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  /// 🗑 Song removed from project
  static Future<void> songRemoved() => HapticFeedback.heavyImpact();

  /// 📋 Song duplicated
  static Future<void> duplicated() => HapticFeedback.mediumImpact();

  /// ✏️ Song renamed
  static Future<void> renamed() => HapticFeedback.lightImpact();

  /// 🔀 Merge started
  static Future<void> mergeStart() => HapticFeedback.mediumImpact();

  /// ✅ Merge complete — triple pulse
  static Future<void> mergeComplete() => celebrate();

  /// ❌ Merge failed
  static Future<void> mergeFailed() => error();

  /// 📁 Project created
  static Future<void> projectCreated() => success();

  /// 🗑 Project deleted
  static Future<void> projectDeleted() => HapticFeedback.heavyImpact();

  /// 🔊 Volume preset tapped (Mute / 50% / 100% / 150%)
  static Future<void> presetTap() => HapticFeedback.selectionClick();

  /// 🎚 Volume slider start drag
  static Future<void> sliderStart() => HapticFeedback.lightImpact();

  /// 🎚 Volume slider end drag
  static Future<void> sliderEnd() => HapticFeedback.selectionClick();

  /// ↕ Reorder drag detected
  static Future<void> reorderStart() => HapticFeedback.mediumImpact();

  /// ↕ Reorder item dropped
  static Future<void> reorderDrop() => HapticFeedback.lightImpact();

  /// ⋮ More menu opened
  static Future<void> menuOpen() => HapticFeedback.lightImpact();

  /// ▼ Expand song tile
  static Future<void> expand() => HapticFeedback.selectionClick();

  /// ▲ Collapse song tile
  static Future<void> collapse() => HapticFeedback.selectionClick();
}