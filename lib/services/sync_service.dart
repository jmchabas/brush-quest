import 'package:cloud_firestore/cloud_firestore.dart';
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
  ];

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
    for (final key in _syncKeys) {
      if (prefs.containsKey(key)) {
        final val = prefs.get(key);
        if (val is List<String>) {
          data[key] = val;
        } else {
          data[key] = val;
        }
      }
    }

    final historyJson = prefs.getStringList('brush_history') ?? [];
    data['brush_history'] = historyJson;
    data['last_sync'] = FieldValue.serverTimestamp();

    await doc.set(data, SetOptions(merge: true));
  }

  /// Download cloud progress and overwrite local data.
  Future<bool> downloadProgress() async {
    final doc = _userDoc;
    if (doc == null) return false;

    final snap = await doc.get();
    if (!snap.exists) return false;

    final data = snap.data() as Map<String, dynamic>?;
    if (data == null || data.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();

    for (final key in _syncKeys) {
      if (data.containsKey(key)) {
        final val = data[key];
        if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is String) {
          await prefs.setString(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, val.cast<String>());
        }
      }
    }

    if (data.containsKey('brush_history') && data['brush_history'] is List) {
      await prefs.setStringList(
        'brush_history',
        (data['brush_history'] as List).cast<String>(),
      );
    }

    return true;
  }

  /// Smart merge: keep whichever side has more progress.
  Future<void> smartSync() async {
    final doc = _userDoc;
    if (doc == null) return;

    final snap = await doc.get();
    if (!snap.exists) {
      await uploadProgress();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cloudData = snap.data() as Map<String, dynamic>? ?? {};

    final localBrushes = prefs.getInt('total_brushes') ?? 0;
    final cloudBrushes = (cloudData['total_brushes'] as int?) ?? 0;

    if (cloudBrushes > localBrushes) {
      await downloadProgress();
    } else {
      await uploadProgress();
    }
  }
}
