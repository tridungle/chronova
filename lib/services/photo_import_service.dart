import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/models/photo.dart';
import '../data/repositories/photo_repository.dart';
import 'exif_service.dart';

/// Result of a batch photo import operation.
class ImportResult {
  final int totalFiles;
  final int successCount;
  final int failedCount;
  final int withExifDate;
  final int withGps;
  final List<Photo> photos;

  const ImportResult({
    required this.totalFiles,
    required this.successCount,
    required this.failedCount,
    required this.withExifDate,
    required this.withGps,
    required this.photos,
  });
}

/// Service responsible for importing photos and processing their EXIF data.
class PhotoImportService {
  final ExifService _exifService;
  final PhotoRepository _photoRepository;
  final ImagePicker _picker;
  final _uuid = const Uuid();

  PhotoImportService({
    ExifService? exifService,
    PhotoRepository? photoRepository,
    ImagePicker? picker,
  }) : _exifService = exifService ?? ExifService(),
       _photoRepository = photoRepository ?? PhotoRepository(),
       _picker = picker ?? ImagePicker();

  /// Pick multiple photos from gallery and import them.
  /// [onProgress] callback reports (current, total) for UI updates.
  Future<ImportResult> pickAndImportPhotos({
    String? tripId,
    void Function(int current, int total)? onProgress,
  }) async {
    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 100,
      requestFullMetadata: true,
    );

    if (pickedFiles.isEmpty) {
      return const ImportResult(
        totalFiles: 0,
        successCount: 0,
        failedCount: 0,
        withExifDate: 0,
        withGps: 0,
        photos: [],
      );
    }

    return _processFiles(
      files: pickedFiles.map((f) => File(f.path)).toList(),
      tripId: tripId,
      onProgress: onProgress,
    );
  }

  /// Import photos from a list of file paths.
  Future<ImportResult> importFromPaths({
    required List<String> paths,
    String? tripId,
    void Function(int current, int total)? onProgress,
  }) async {
    final files = paths.map((p) => File(p)).toList();
    return _processFiles(files: files, tripId: tripId, onProgress: onProgress);
  }

  /// Core processing: read EXIF, copy to app storage, save to DB.
  Future<ImportResult> _processFiles({
    required List<File> files,
    String? tripId,
    void Function(int current, int total)? onProgress,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final photos = <Photo>[];
    int successCount = 0;
    int failedCount = 0;
    int withExifDate = 0;
    int withGps = 0;

    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length);

      try {
        final file = files[i];
        if (!await file.exists()) {
          failedCount++;
          continue;
        }

        // Extract EXIF
        final exif = await _exifService.extractFromFile(file.path);

        // Copy file to app storage
        final id = _uuid.v4();
        final ext = p.extension(file.path).toLowerCase();
        final destPath = p.join(photosDir.path, '$id$ext');
        await file.copy(destPath);

        // Get file size
        final fileSize = await file.length();

        final now = DateTime.now();
        final photo = Photo(
          id: id,
          filePath: destPath,
          tripId: tripId,
          dateTaken: exif.dateTaken,
          latitude: exif.latitude,
          longitude: exif.longitude,
          altitude: exif.altitude,
          cameraModel: exif.cameraModel,
          width: exif.width,
          height: exif.height,
          fileSize: fileSize,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        );

        photos.add(photo);
        successCount++;
        if (exif.hasDate) withExifDate++;
        if (exif.hasLocation) withGps++;
      } catch (e) {
        debugPrint('Failed to import photo: $e');
        failedCount++;
      }
    }

    // Batch insert into database
    if (photos.isNotEmpty) {
      await _photoRepository.insertAll(photos);
    }

    return ImportResult(
      totalFiles: files.length,
      successCount: successCount,
      failedCount: failedCount,
      withExifDate: withExifDate,
      withGps: withGps,
      photos: photos,
    );
  }
}
