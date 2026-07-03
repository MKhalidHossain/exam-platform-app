import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _sourcePath = 'assets/images/app_logo.png';
const _standardPath = 'assets/images/app_launcher_icon.png';
const _foregroundPath = 'assets/images/app_launcher_foreground.png';
const _canvasSize = 1024;
const _logoMaxSize = 820;
const _brandBlue = [0x0b, 0x6e, 0xa8];

void main() {
  final sourceBytes = File(_sourcePath).readAsBytesSync();
  final source = img.decodePng(sourceBytes);
  if (source == null) {
    throw StateError('Unable to decode $_sourcePath');
  }

  final trimmed = _trimTransparentPadding(source);
  final scale = _logoMaxSize / math.max(trimmed.width, trimmed.height);
  final logo = img.copyResize(
    trimmed,
    width: (trimmed.width * scale).round(),
    height: (trimmed.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );

  final standard = img.Image(
    width: _canvasSize,
    height: _canvasSize,
    numChannels: 4,
  );
  img.fill(
    standard,
    color: img.ColorUint8.rgba(_brandBlue[0], _brandBlue[1], _brandBlue[2], 255),
  );
  img.compositeImage(standard, logo, center: true);

  final foreground = img.Image(
    width: _canvasSize,
    height: _canvasSize,
    numChannels: 4,
  );
  img.fill(foreground, color: img.ColorUint8.rgba(0, 0, 0, 0));
  img.compositeImage(foreground, logo, center: true);

  File(_standardPath).writeAsBytesSync(img.encodePng(standard));
  File(_foregroundPath).writeAsBytesSync(img.encodePng(foreground));
}

img.Image _trimTransparentPadding(img.Image source) {
  var minX = source.width;
  var minY = source.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a > 8) {
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
  }

  if (maxX < minX || maxY < minY) {
    return source;
  }

  return img.copyCrop(
    source,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}
