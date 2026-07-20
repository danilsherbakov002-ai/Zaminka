import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class CacheProgress {
  final String trackId;
  final double progress; // 0..1
  final bool done;

  CacheProgress({required this.trackId, required this.progress, required this.done});
}

/// Управляет кэшированием потокового аудио и принудительным оффлайн-сохранением.
///
/// - "cache" — временная директория (может быть очищена ОС), пишется
///   автоматически во время обычного прослушивания.
/// - "offline" — постоянная директория (documents), пишется только
///   по явному запросу пользователя ("Сохранить для оффлайна").
class OfflineCacheManager {
  final Dio _dio = Dio();
  final _progressController = StreamController<CacheProgress>.broadcast();

  Stream<CacheProgress> get progressStream => _progressController.stream;

  Future<Directory> _cacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/direx_stream_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _offlineDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/direx_offline');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _cacheFile(String trackId) async => File('${(await _cacheDir()).path}/$trackId.mp3');
  Future<File> _offlineFile(String trackId) async => File('${(await _offlineDir()).path}/$trackId.mp3');

  /// Автокэш во время обычного прослушивания (буферизация потока в фоне).
  Future<String?> cacheWhilePlaying(String trackId, String streamUrl) async {
    final file = await _cacheFile(trackId);
    if (await file.exists()) return file.path;

    try {
      await _dio.download(
        streamUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          _progressController.add(
            CacheProgress(trackId: trackId, progress: received / total, done: false),
          );
        },
      );
      _progressController.add(CacheProgress(trackId: trackId, progress: 1, done: true));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Принудительное сохранение трека для полноценного оффлайн-воспроизведения.
  Future<String?> saveForOffline(String trackId, String streamUrl) async {
    final offlineFile = await _offlineFile(trackId);
    if (await offlineFile.exists()) return offlineFile.path;

    final cacheFile = await _cacheFile(trackId);
    if (await cacheFile.exists()) {
      await cacheFile.copy(offlineFile.path);
      _progressController.add(CacheProgress(trackId: trackId, progress: 1, done: true));
      return offlineFile.path;
    }

    try {
      await _dio.download(
        streamUrl,
        offlineFile.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          _progressController.add(
            CacheProgress(trackId: trackId, progress: received / total, done: false),
          );
        },
      );
      _progressController.add(CacheProgress(trackId: trackId, progress: 1, done: true));
      return offlineFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAvailableOffline(String trackId) async => (await _offlineFile(trackId)).exists();

  /// Возвращает путь к локальному файлу (оффлайн → кэш → иначе исходный URL).
  Future<String> getPlaybackSource(String trackId, String streamUrl) async {
    final offline = await _offlineFile(trackId);
    if (await offline.exists()) return offline.path;

    final cached = await _cacheFile(trackId);
    if (await cached.exists()) return cached.path;

    return streamUrl;
  }

  Future<void> removeOffline(String trackId) async {
    final file = await _offlineFile(trackId);
    if (await file.exists()) await file.delete();
  }

  Future<int> getCacheSizeBytes() async {
    final dir = await _cacheDir();
    int total = 0;
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  void dispose() {
    _progressController.close();
  }
}
