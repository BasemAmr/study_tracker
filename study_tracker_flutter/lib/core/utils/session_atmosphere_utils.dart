import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> getSessionOverlayImagesDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'session_overlays'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String?> pickAndStoreSessionOverlayImage() async {
  final overlaysDir = await getSessionOverlayImagesDirectory();
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Choose overlay background image',
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    initialDirectory: overlaysDir.path,
    allowMultiple: false,
  );

  if (result == null || result.files.isEmpty) return null;

  final sourcePath = result.files.single.path;
  if (sourcePath == null || sourcePath.isEmpty) return null;

  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) return null;

  final ext = p.extension(sourcePath).toLowerCase();
  final targetName = 'overlay_${DateTime.now().millisecondsSinceEpoch}$ext';
  final targetPath = p.join(overlaysDir.path, targetName);
  await sourceFile.copy(targetPath);
  try {
    await FilePicker.platform.clearTemporaryFiles();
  } catch (_) {
    // Some platforms do not support temp cleanup.
  }
  return targetPath;
}

bool isAssetBackgroundPath(String path) => path.startsWith('assets/');
