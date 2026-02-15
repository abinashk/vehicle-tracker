import 'package:test/test.dart';
import 'package:shared/shared.dart';

void main() {
  group('PlateNormalizer', () {
    test('should normalize Devanagari digits to Latin', () {
      expect(
        PlateNormalizer.normalize('BA १ PA १२३४'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should normalize full Devanagari plate', () {
      expect(
        PlateNormalizer.normalize('बा १ पा १२३४'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should uppercase Latin input', () {
      expect(
        PlateNormalizer.normalize('ba 1 pa 1234'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should insert spaces between letter and digit groups', () {
      expect(
        PlateNormalizer.normalize('BA1PA1234'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should collapse multiple spaces', () {
      expect(
        PlateNormalizer.normalize('BA  1  PA  1234'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should strip non-alphanumeric characters', () {
      expect(
        PlateNormalizer.normalize('BA-1-PA-1234'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should handle already normalized input', () {
      expect(
        PlateNormalizer.normalize('BA 1 PA 1234'),
        equals('BA 1 PA 1234'),
      );
    });

    test('should handle Narayani zone format', () {
      expect(
        PlateNormalizer.normalize('ना १ ज १२३४'),
        equals('NA 1 JA 1234'),
      );
    });

    test('should trim whitespace', () {
      expect(
        PlateNormalizer.normalize('  BA 1 PA 1234  '),
        equals('BA 1 PA 1234'),
      );
    });

    group('compact', () {
      test('should strip all spaces', () {
        expect(
          PlateNormalizer.compact('BA 1 PA 1234'),
          equals('BA1PA1234'),
        );
      });
    });
  });
}
