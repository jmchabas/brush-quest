import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CosmeticItem {
  final String id;
  final String name;
  final int cost;
  final Color color;
  final bool isAnimated; // for legendary rainbow gradient

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.color,
    this.isAnimated = false,
  });
}

/// Manages decorative hero portrait frames (cosmetic ring/border).
///
/// SharedPreferences keys used:
///   - 'unlocked_cosmetics' (StringList)
///   - 'selected_cosmetic' (String)
/// NOTE: These keys need to be added to the settings reset flow.
class CosmeticService {
  // SharedPreferences keys
  static const _unlockedKey = 'unlocked_cosmetics';
  static const _selectedKey = 'selected_cosmetic';
  static bool _purchasing = false;

  static const List<CosmeticItem> allCosmetics = [
    CosmeticItem(
      id: 'bronze',
      name: 'BRONZE FRAME',
      cost: 3,
      color: Color(0xFFCD7F32),
    ),
    CosmeticItem(
      id: 'silver',
      name: 'SILVER FRAME',
      cost: 6,
      color: Color(0xFFC0C0C0),
    ),
    CosmeticItem(
      id: 'gold',
      name: 'GOLD FRAME',
      cost: 9,
      color: Color(0xFFFFD700),
    ),
    CosmeticItem(
      id: 'crystal',
      name: 'CRYSTAL FRAME',
      cost: 11,
      color: Color(0xFF00E5FF),
    ),
    CosmeticItem(
      id: 'emerald',
      name: 'EMERALD FRAME',
      cost: 13,
      color: Color(0xFF50C878),
    ),
    CosmeticItem(
      id: 'ruby',
      name: 'RUBY FRAME',
      cost: 15,
      color: Color(0xFFE0115F),
    ),
    CosmeticItem(
      id: 'legendary',
      name: 'LEGENDARY FRAME',
      cost: 17,
      color: Color(0xFFAA00FF),
      isAnimated: true,
    ),
  ];

  Future<List<String>> getUnlockedCosmeticIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedKey) ?? [];
  }

  Future<String?> getSelectedCosmeticId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }

  Future<CosmeticItem?> getSelected() async {
    final id = await getSelectedCosmeticId();
    if (id == null) return null;
    return getCosmeticById(id);
  }

  bool get hasSelected => allCosmetics.any((c) => c.id == _cachedSelectedId);
  String? _cachedSelectedId;

  Future<void> select(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
    _cachedSelectedId = id;
  }

  Future<void> deselect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedKey);
    _cachedSelectedId = null;
  }

  Future<bool> unlock(String cosmeticId) async {
    if (_purchasing) return false;
    _purchasing = true;
    try {
      final cosmetic = getCosmeticById(cosmeticId);
      if (cosmetic == null) return false;
      final prefs = await SharedPreferences.getInstance();

      final unlocked = prefs.getStringList(_unlockedKey) ?? [];
      if (unlocked.contains(cosmeticId)) return true;

      final stars = prefs.getInt('total_stars') ?? 0;
      if (stars < cosmetic.cost) return false;

      await prefs.setInt('total_stars', stars - cosmetic.cost);
      unlocked.add(cosmeticId);
      await prefs.setStringList(_unlockedKey, unlocked);
      return true;
    } finally {
      _purchasing = false;
    }
  }

  Future<bool> isCosmeticUnlocked(String cosmeticId) async {
    final unlocked = await getUnlockedCosmeticIds();
    return unlocked.contains(cosmeticId);
  }

  Color? getSelectedColor() {
    if (_cachedSelectedId == null) return null;
    final cosmetic = getCosmeticById(_cachedSelectedId!);
    return cosmetic?.color;
  }

  /// Refreshes the cached selected ID from SharedPreferences.
  Future<void> refreshCache() async {
    _cachedSelectedId = await getSelectedCosmeticId();
  }

  static CosmeticItem? getCosmeticById(String id) {
    try {
      return allCosmetics.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
