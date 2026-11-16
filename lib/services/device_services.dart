import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of an attempt to use a device feature: either a value or a
/// plain-language reason why it was not available (NFR7).
class DeviceResult<T> {
  const DeviceResult.ok(T this.value) : error = null;
  const DeviceResult.failed(String this.error) : value = null;

  final T? value;
  final String? error;
}

/// Camera and gallery access for report photos (FR19). Picked photos are
/// copied into the app's own folder so they stay available later.
class PhotoService {
  final _picker = ImagePicker();

  Future<DeviceResult<List<String>>> takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (file == null) return const DeviceResult.ok([]);
      return DeviceResult.ok([await _keep(file)]);
    } on PlatformException {
      return const DeviceResult.failed(
          'The camera is not available. Check the camera permission in your phone settings, '
          'or choose a photo from the gallery.');
    }
  }

  Future<DeviceResult<List<String>>> pickFromGallery({required int limit}) async {
    try {
      final files = limit == 1
          ? [?await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 75)]
          : await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 75, limit: limit);
      final kept = <String>[];
      for (final file in files.take(limit)) {
        kept.add(await _keep(file));
      }
      return DeviceResult.ok(kept);
    } on PlatformException {
      return const DeviceResult.failed(
          'The photo library is not available. Check the photos permission in your phone settings.');
    }
  }

  Future<String> _keep(XFile file) async {
    // The browser preview has no app folder; keep the picked image's URL.
    if (kIsWeb) return file.path;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'photos'));
    await dir.create(recursive: true);
    final target = p.join(
        dir.path, '${DateTime.now().microsecondsSinceEpoch}${p.extension(file.path)}');
    await file.saveTo(target);
    return target;
  }
}

/// One-off location lookup for the "Use my location" button. The location
/// field can always be typed instead, so failure never blocks a report (FR6).
class LocationService {
  Future<DeviceResult<String>> currentLocationText() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceResult.failed(
            'Location is turned off on this phone. Type the building, room or area instead.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const DeviceResult.failed(
            'Location permission was refused. Type the building, room or area instead.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return DeviceResult.ok(
          'GPS ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } catch (_) {
      return const DeviceResult.failed(
          'Your location could not be found. Type the building, room or area instead.');
    }
  }
}
