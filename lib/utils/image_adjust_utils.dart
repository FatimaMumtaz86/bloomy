import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

enum MediaAdjustTarget { postOrPin, avatar }

class AdjustedImageSelection {
  final XFile file;
  final Uint8List? uploadBytes;
  final String? fileName;

  const AdjustedImageSelection({
    required this.file,
    this.uploadBytes,
    this.fileName,
  });
}

Future<AdjustedImageSelection?> pickAndAdjustImage({
  required BuildContext context,
  required ImagePicker picker,
  required MediaAdjustTarget target,
}) async {
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) {
    return null;
  }
  return adjustPickedImage(
    context: context,
    pickedFile: picked,
    target: target,
  );
}

Future<AdjustedImageSelection?> adjustPickedImage({
  required BuildContext context,
  required XFile pickedFile,
  required MediaAdjustTarget target,
}) async {
  final cropper = ImageCropper();
  final ratio = target == MediaAdjustTarget.avatar
      ? const CropAspectRatio(ratioX: 1, ratioY: 1)
      : const CropAspectRatio(ratioX: 4, ratioY: 5);

  final cropped = await cropper.cropImage(
    sourcePath: pickedFile.path,
    aspectRatio: ratio,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 92,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: target == MediaAdjustTarget.avatar
            ? 'Adjust profile photo'
            : 'Adjust image',
        toolbarWidgetColor: Colors.white,
        lockAspectRatio: true,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: target == MediaAdjustTarget.avatar
            ? 'Adjust profile photo'
            : 'Adjust image',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        size: const CropperSize(width: 520, height: 680),
      ),
    ],
  );

  if (cropped == null) {
    return null;
  }

  final resolvedName = pickedFile.name.isNotEmpty
      ? pickedFile.name
      : 'adjusted-${DateTime.now().millisecondsSinceEpoch}.jpg';

  final uploadBytes = kIsWeb ? await cropped.readAsBytes() : null;
  return AdjustedImageSelection(
    file: XFile(cropped.path, name: resolvedName),
    uploadBytes: uploadBytes,
    fileName: resolvedName,
  );
}
