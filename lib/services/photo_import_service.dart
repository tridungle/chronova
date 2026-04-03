import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/photo_path_resolver.dart';
import '../data/models/photo.dart';
import '../data/repositories/photo_repository.dart';
import 'exif_service.dart';

/// Result of a batch photo import operation.
class ImportResult {
  final int totalFiles;
  final int successCount;
  final int failedCount;
  final int duplicateCount;
  final int withExifDate;
  final int withGps;
  final List<Photo> photos;

  const ImportResult({
    required this.totalFiles,
    required this.successCount,
    required this.failedCount,
    required this.duplicateCount,
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
        duplicateCount: 0,
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

  /// Take a photo with the camera and import it.
  Future<ImportResult> takeAndImportPhoto({
    String? tripId,
    void Function(int current, int total)? onProgress,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      requestFullMetadata: true,
    );

    if (pickedFile == null) {
      return const ImportResult(
        totalFiles: 0,
        successCount: 0,
        failedCount: 0,
        duplicateCount: 0,
        withExifDate: 0,
        withGps: 0,
        photos: [],
      );
    }

    return _processFiles(
      files: [File(pickedFile.path)],
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

  /// Core processing: read EXIF, compute hash, skip duplicates, copy to app
  /// storage, save to DB.
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
    int duplicateCount = 0;
    int withExifDate = 0;
    int withGps = 0;

    // Track hashes within this batch to catch duplicates within the same import
    final batchHashes = <String>{};

    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length);

      try {
        final file = files[i];
        if (!await file.exists()) {
          failedCount++;
          continue;
        }

        // Compute SHA-256 hash of the file content for duplicate detection
        final fileHash = await _computeFileHash(file);

        // Check for duplicates: within this batch AND in the database
        if (batchHashes.contains(fileHash) ||
            await _photoRepository.existsByHash(fileHash)) {
          duplicateCount++;
          continue;
        }
        batchHashes.add(fileHash);

        // Extract EXIF
        final exif = await _exifService.extractFromFile(file.path);

        // Copy file to app storage
        final id = _uuid.v4();
        final ext = p.extension(file.path).toLowerCase();
        final destPath = p.join(photosDir.path, '$id$ext');
        await file.copy(destPath);

        // Store relative path in DB so it survives sandbox UUID changes
        final resolver = PhotoPathResolver.instance;
        await resolver.init();
        final relativePath = resolver.toRelative(destPath);

        // Get file size
        final fileSize = await file.length();

        final now = DateTime.now();
        final photo = Photo(
          id: id,
          filePath: relativePath,
          tripId: tripId,
          dateTaken: exif.dateTaken,
          latitude: exif.latitude,
          longitude: exif.longitude,
          altitude: exif.altitude,
          cameraModel: exif.cameraModel,
          width: exif.width,
          height: exif.height,
          fileSize: fileSize,
          fileHash: fileHash,
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
      duplicateCount: duplicateCount,
      withExifDate: withExifDate,
      withGps: withGps,
      photos: photos,
    );
  }

  /// Compute SHA-256 hash of a file's content.
  ///
  /// Reads the file as a stream to avoid loading the entire file into memory,
  /// which is important for large photo files.
  static Future<String> computeFileHash(File file) => _computeFileHash(file);

  static Future<String> _computeFileHash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
