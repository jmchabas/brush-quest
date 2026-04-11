import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Syncs local SharedPreferences progress to/from Firestore.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _db = FirebaseFirestore.instance;

  static const _syncKeys = [
    'total_stars',
    'current_streak',
    'best_streak',
    'last_brush_date',
    'today_brush_count',
    'today_date',
    'total_brushes',
    'unlocked_heroes',
    'selected_hero',
    'unlocked_weapons',
    'selected_weapon',
    'current_world',
    'morning_done_date',
    'evening_done_date',
    'phase_duration',
    'camera_enabled',
    'muted',
    'onboarding_completed',
    'last_greeting_date',
    'voice_style',
    'star_wallet',
    'trophy_captured',
    'unlocked_evolutions',
    'streak_pause_until',
    'last_daily_bonus_date',
    'camera_prompt_shown',
  ];
  static const _prefixSyncKeys = ['world_progress_', 'achievement_', 'trophy_defeats_', 'evolution_stage_', 'has_seen_first_', 'world_intro_seen_'];

  DocumentReference? get _userDoc {
    final user = AuthService().currentUser;
    if (user == null) return null;
    return _db.collection('users').doc(user.uid);
  }

  /// Upload local progress to Firestore.
  Future<void> uploadProgress() async {
    final doc = _userDoc;
    if (doc == null) return;
    final prefs = await SharedPreferences.getInstance();

    final data = <String, dynamic>{};
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (_shouldSyncKey(key)) {
        final val = prefs.get(key);
        if (val != null) data[key] = val;
      }
    }

    final historyJson = prefs.getStringList('brush_history') ?? [];
    data['brush_history'] = historyJson;
    data['last_sync'] = FieldValue.serverTimestamp();
    data['sync_version'] = 2;

    try {
      await doc
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      // Persist last sync timestamp locally for UI display
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString(
          'last_cloud_save', DateTime.now().toIso8601String());
    } on TimeoutException {
      throw Exception('Cloud save timed out. Please check your connection.');
    }
  }

  /// Download cloud progress and overwrite local data.
  Future<bool> downloadProgress() async {
    final doc = _userDoc;
    if (doc == null) return false;

    final DocumentSnapshot snap;
    try {
      snap = await doc.get().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception(
          'Cloud restore timed out. Please check your connection.');
    }
    if (!snap.exists) return false;

    final data = snap.data() as Map<String, dynamic>?;
    if (data == null || data.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();

    for (final entry in data.entries) {
      if (!_shouldSyncKey(entry.key)) continue;
      await _writeValue(prefs, entry.key, entry.value);
    }

    return true;
  }

  /// Smart merge: keep whichever side has more progress.
  Future<void> smartSync() async {
    final doc = _userDoc;
    if (doc == null) return;

    final DocumentSnapshot snap;
    try {
      snap = await doc.get().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Silently fall back — smartSync is best-effort
      return;
    }
    if (!snap.exists) {
      await uploadProgress();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cloudData = snap.data() as Map<String, dynamic>? ?? {};

    final localScore = _progressScoreFromPrefs(prefs);
    final cloudScore = _progressScoreFromCloud(cloudData);

    if (cloudScore > localScore) {
      await downloadProgress();
    } else {
      await uploadProgress();
    }
  }

  /// Delete the user's Firestore document (cloud data).
  Future<bool> deleteCloudData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete cloud data: $e');
      return false;
    }
  }

  bool _shouldSyncKey(String key) {
    if (_syncKeys.contains(key)) return true;
    if (key == 'brush_history') return true;
    return _prefixSyncKeys.any((prefix) => key.startsWith(prefix));
  }

  Future<void> _writeValue(SharedPreferences prefs, String key, dynamic val) async {
    try {
      if (val is int) {
        await prefs.setInt(key, val);
      } else if (val is String) {
        await prefs.setString(key, val);
      } else if (val is bool) {
        await prefs.setBool(key, val);
      } else if (val is double) {
        await prefs.setDouble(key, val);
      } else if (val is List) {
        try {
          final stringList = val.whereType<String>().toList();
          await prefs.setStringList(key, stringList);
        } catch (e) {
          debugPrint('Sync: failed to write list for $key: $e');
        }
      }
    } catch (e) {
      debugPrint('Sync: failed to write $key: $e');
    }
  }

  int _progressScoreFromPrefs(SharedPreferences prefs) {
    final brushes = prefs.getInt('total_brushes') ?? 0;
    final stars = prefs.getInt('total_stars') ?? 0;
    final heroes = (prefs.getStringList('unlocked_heroes') ?? const []).length;
    final weapons = (prefs.getStringList('unlocked_weapons') ?? const []).length;
    final trophies = (prefs.getStringList('trophy_captured') ?? const []).length;
    final keys = prefs.getKeys();
    final achievements = keys.where((k) => k.startsWith('achievement_') && (prefs.getBool(k) ?? false)).length;
    final worldProgress = keys
        .where((k) => k.startsWith('world_progress_'))
        .fold<int>(0, (acc, key) => acc + (prefs.getInt(key) ?? 0));
    return brushes * 8 + stars * 5 + heroes * 30 + weapons * 20 + achievements * 15 + worldProgress * 3 + trophies * 25;
  }

  int _progressScoreFromCloud(Map<String, dynamic> cloudData) {
    int sumWorldProgress = 0;
    int achievements = 0;
    cloudData.forEach((key, value) {
      if (key.startsWith('world_progress_') && value is int) {
        sumWorldProgress += value;
      }
      if (key.startsWith('achievement_') && value == true) {
        achievements++;
      }
    });
    final brushes = (cloudData['total_brushes'] as int?) ?? 0;
    final stars = (cloudData['total_stars'] as int?) ?? 0;
    final heroes = (cloudData['unlocked_heroes'] is List) ? (cloudData['unlocked_heroes'] as List).length : 0;
    final weapons = (cloudData['unlocked_weapons'] is List) ? (cloudData['unlocked_weapons'] as List).length : 0;
    final trophies = (cloudData['trophy_captured'] is List) ? (cloudData['trophy_captured'] as List).length : 0;
    return brushes * 8 + stars * 5 + heroes * 30 + weapons * 20 + achievements * 15 + sumWorldProgress * 3 + trophies * 25;
  }
}
