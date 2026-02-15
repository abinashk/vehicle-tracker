import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared/shared.dart';

/// OCR result containing the recognized and normalized plate number.
class OcrResult {
  final String normalizedPlate;
  final String rawText;
  final double confidence;

  const OcrResult({
    required this.normalizedPlate,
    required this.rawText,
    required this.confidence,
  });
}

/// On-device plate number extraction using Google ML Kit Text Recognition.
///
/// Supports both Latin and Devanagari scripts.
/// Processes camera images and pipes results through [PlateNormalizer.normalize]
/// from the shared package.
///
/// Target: extraction within 3 seconds.
class OcrService {
  OcrService();

  TextRecognizer? _latinRecognizer;
  TextRecognizer? _devanagariRecognizer;

  /// Initialize recognizers lazily.
  TextRecognizer get _latin =>
      _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  TextRecognizer get _devanagari => _devanagariRecognizer ??=
      TextRecognizer(script: TextRecognitionScript.devanagari);

  /// Extract plate number from an image file.
  ///
  /// Runs both Latin and Devanagari recognition in parallel,
  /// then selects the best candidate based on plate pattern matching.
  Future<OcrResult?> extractPlateNumber(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    // Run both recognizers concurrently for speed.
    final results = await Future.wait([
      _latin.processImage(inputImage),
      _devanagari.processImage(inputImage),
    ]);

    final latinText = results[0];
    final devanagariText = results[1];

    // Collect all text blocks from both recognizers.
    final candidates = <_PlateCandidate>[];

    for (final block in latinText.blocks) {
      for (final line in block.lines) {
        final normalized = PlateNormalizer.normalize(line.text);
        if (_isPlateCandidate(normalized)) {
          candidates.add(_PlateCandidate(
            normalized: normalized,
            raw: line.text,
            confidence: _calculateConfidence(line),
          ));
        }
      }
    }

    for (final block in devanagariText.blocks) {
      for (final line in block.lines) {
        final normalized = PlateNormalizer.normalize(line.text);
        if (_isPlateCandidate(normalized)) {
          candidates.add(_PlateCandidate(
            normalized: normalized,
            raw: line.text,
            confidence: _calculateConfidence(line),
          ));
        }
      }
    }

    if (candidates.isEmpty) {
      // Fall back to returning the largest text block.
      final allBlocks = [...latinText.blocks, ...devanagariText.blocks];
      if (allBlocks.isEmpty) return null;

      allBlocks.sort((a, b) => b.text.length.compareTo(a.text.length));
      final best = allBlocks.first;
      final normalized = PlateNormalizer.normalize(best.text);
      return OcrResult(
        normalizedPlate: normalized,
        rawText: best.text,
        confidence: 0.3,
      );
    }

    // Sort by confidence descending and return the best candidate.
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final best = candidates.first;

    return OcrResult(
      normalizedPlate: best.normalized,
      rawText: best.raw,
      confidence: best.confidence,
    );
  }

  /// Check if a normalized string looks like a plate number.
  bool _isPlateCandidate(String normalized) {
    if (normalized.length < 4) return false;
    // Must contain at least some letters and some digits.
    final hasLetters = RegExp(r'[A-Z]').hasMatch(normalized);
    final hasDigits = RegExp(r'\d').hasMatch(normalized);
    return hasLetters && hasDigits;
  }

  /// Calculate a confidence score based on line properties.
  double _calculateConfidence(TextLine line) {
    double confidence = 0.5;

    // Longer text that matches plate pattern gets higher confidence.
    final normalized = PlateNormalizer.normalize(line.text);
    if (PlateRegex.normalizedPlatePattern.hasMatch(normalized)) {
      confidence += 0.4;
    }

    // Reasonable length for a plate number.
    if (normalized.replaceAll(' ', '').length >= 7 &&
        normalized.replaceAll(' ', '').length <= 14) {
      confidence += 0.1;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Dispose recognizers to free resources.
  void dispose() {
    _latinRecognizer?.close();
    _devanagariRecognizer?.close();
  }
}

class _PlateCandidate {
  final String normalized;
  final String raw;
  final double confidence;

  const _PlateCandidate({
    required this.normalized,
    required this.raw,
    required this.confidence,
  });
}

/// Provider for the OCR service.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
