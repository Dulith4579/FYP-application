import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/medical_timeline_card.dart';

/// A pure-Dart local database caching service powered by Hive.
/// 
/// Automatically stores decrypted/encrypted clinical records on client devices 
/// to enable true offline-first PHR viewing and cross-session persistence.
class LocalCacheService {
  static const String boxName = 'medical_timeline_cache';

  /// Initializes Hive storage and opens the timeline cache box.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(boxName);
  }

  static Box<String> get _box => Hive.box<String>(boxName);

  /// Caches a list of raw medical log documents (maps) retrieved from Firestore.
  static Future<void> cacheTimeline(String patientId, List<Map<String, dynamic>> logs) async {
    final listJson = json.encode(logs);
    await _box.put('timeline_$patientId', listJson);
  }

  /// Retrieves the cached medical timeline logs for a patient from the Hive database.
  static List<MedicalLog> getCachedTimeline(String patientId) {
    final listJson = _box.get('timeline_$patientId');
    if (listJson == null || listJson.isEmpty) return [];
    try {
      final decodedList = json.decode(listJson) as List<dynamic>;
      return decodedList.map((item) {
        return MedicalLog.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
