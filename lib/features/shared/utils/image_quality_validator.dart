import 'dart:io';
import 'package:image/image.dart' as img;

class ImageQualityResult {
  final bool isValid;
  final String? errorMessage;
  final double averageBrightness;
  final double blurScore;

  ImageQualityResult({
    required this.isValid,
    this.errorMessage,
    required this.averageBrightness,
    required this.blurScore,
  });
}

class ImageQualityValidator {
  /// Evaluates an image for brightness (exposure) and blur (gradient sharpness).
  static Future<ImageQualityResult> validateImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ImageQualityResult(
          isValid: false,
          errorMessage: 'Failed to decode image file.',
          averageBrightness: 0,
          blurScore: 0,
        );
      }

      // Step-sample the image to analyze brightness and sharpness extremely fast
      // (Scanning a 1080p image pixel-by-pixel in Dart can block the UI thread,
      // so we use a step size of 4 to analyze 1/16th of the pixels)
      double totalLuminance = 0;
      int sampleCount = 0;
      double totalGradient = 0;

      final width = image.width;
      final height = image.height;
      const step = 4;

      for (int y = step; y < height - step; y += step) {
        for (int x = step; x < width - step; x += step) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          // Standard relative luminance formula
          final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
          totalLuminance += luminance;
          sampleCount++;

          // Sobel-like edge gradient calculation
          final pixelLeft = image.getPixel(x - 1, y);
          final pixelRight = image.getPixel(x + 1, y);
          final pixelUp = image.getPixel(x, y - 1);
          final pixelDown = image.getPixel(x, y + 1);

          final lumLeft =
              0.299 * pixelLeft.r.toDouble() +
              0.587 * pixelLeft.g.toDouble() +
              0.114 * pixelLeft.b.toDouble();
          final lumRight =
              0.299 * pixelRight.r.toDouble() +
              0.587 * pixelRight.g.toDouble() +
              0.114 * pixelRight.b.toDouble();
          final lumUp =
              0.299 * pixelUp.r.toDouble() +
              0.587 * pixelUp.g.toDouble() +
              0.114 * pixelUp.b.toDouble();
          final lumDown =
              0.299 * pixelDown.r.toDouble() +
              0.587 * pixelDown.g.toDouble() +
              0.114 * pixelDown.b.toDouble();

          final dx = lumRight - lumLeft;
          final dy = lumDown - lumUp;
          final grad = dx.abs() + dy.abs();
          totalGradient += grad;
        }
      }

      if (sampleCount == 0) {
        return ImageQualityResult(
          isValid: false,
          errorMessage: 'Image size is too small.',
          averageBrightness: 0,
          blurScore: 0,
        );
      }

      final avgBrightness = totalLuminance / sampleCount;
      final avgBlurScore = totalGradient / sampleCount;

      // Quality Validation Thresholds
      // Brightness range: 0 (pitch black) to 255 (blinding white)
      if (avgBrightness < 45) {
        return ImageQualityResult(
          isValid: false,
          errorMessage:
              'The photo is too dark. Please move to a brighter area.',
          averageBrightness: avgBrightness,
          blurScore: avgBlurScore,
        );
      }
      if (avgBrightness > 235) {
        return ImageQualityResult(
          isValid: false,
          errorMessage:
              'The photo is too bright (overexposed). Avoid direct light source.',
          averageBrightness: avgBrightness,
          blurScore: avgBlurScore,
        );
      }

      // Sharpness threshold (low edge magnitude indicates a blurry or out-of-focus image)
      // Sharp photos with edge gradients average > 7.5
      if (avgBlurScore < 7.5) {
        return ImageQualityResult(
          isValid: false,
          errorMessage:
              'The photo is blurry. Please hold your camera steady and refocus.',
          averageBrightness: avgBrightness,
          blurScore: avgBlurScore,
        );
      }

      return ImageQualityResult(
        isValid: true,
        averageBrightness: avgBrightness,
        blurScore: avgBlurScore,
      );
    } catch (e) {
      return ImageQualityResult(
        isValid: false,
        errorMessage: 'Error analyzing photo quality: $e',
        averageBrightness: 0,
        blurScore: 0,
      );
    }
  }
}
