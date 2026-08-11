import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:vitalrise/features/anatomy/domain/anatomy_topic.dart';
import 'package:vitalrise/features/exercises/domain/exercise.dart';
import 'package:vitalrise/features/exercises/domain/exercise_library.dart';

/// Guards the assets referenced from Dart against ever going missing.
///
/// A missing animation degrades gracefully at runtime, but silently - so
/// without this test a typo in an asset path would ship and nobody would
/// notice until a user opened the exercise.
void main() {
  group('Lottie animations', () {
    test('every exercise animation file exists', () {
      for (final Exercise e in ExerciseLibrary.all) {
        expect(
          File(e.animation.asset).existsSync(),
          isTrue,
          reason: 'missing ${e.animation.asset} for ${e.id}',
        );
      }
    });

    test(
      'every animation is valid Lottie that the renderer can parse',
      () async {
        for (final Exercise e in ExerciseLibrary.all) {
          final Uint8List bytes = await File(e.animation.asset).readAsBytes();
          final LottieComposition composition =
              await LottieComposition.fromBytes(bytes);

          expect(
            composition.duration.inMilliseconds,
            greaterThan(0),
            reason: e.id,
          );
          expect(
            composition.endFrame,
            greaterThan(composition.startFrame),
            reason: e.id,
          );
        }
      },
    );

    test('animations carry at least one layer of actual motion', () {
      for (final Exercise e in ExerciseLibrary.all) {
        final Map<String, dynamic> json =
            jsonDecode(File(e.animation.asset).readAsStringSync())
                as Map<String, dynamic>;

        final List<dynamic> layers = json['layers'] as List<dynamic>;
        expect(layers, isNotEmpty, reason: e.id);

        // "a": 1 marks an animated property. At least one layer must have
        // one, or the file is a static image with a duration.
        final bool animated = const JsonEncoder()
            .convert(layers)
            .contains('"a":1');
        expect(animated, isTrue, reason: '${e.id} has no animated property');
      }
    });

    test('animation files stay small enough to bundle', () {
      for (final Exercise e in ExerciseLibrary.all) {
        final int bytes = File(e.animation.asset).lengthSync();
        expect(bytes, lessThan(200 * 1024), reason: '${e.id} is $bytes bytes');
      }
    });
  });

  group('anatomy illustrations', () {
    test('every illustration file exists and is non-trivial', () {
      for (final AnatomyTopic t in AnatomyLibrary.all) {
        final File file = File(t.asset);
        expect(file.existsSync(), isTrue, reason: 'missing ${t.asset}');
        expect(file.lengthSync(), greaterThan(500), reason: t.id);
      }
    });

    test('illustrations are well-formed SVG with a viewBox', () {
      for (final AnatomyTopic t in AnatomyLibrary.all) {
        final String svg = File(t.asset).readAsStringSync();
        expect(svg, contains('<svg'), reason: t.id);
        expect(svg, contains('viewBox'), reason: t.id);
        expect(svg.trimRight(), endsWith('</svg>'), reason: t.id);
      }
    });

    test('illustrations carry an accessible label in the file and in Dart', () {
      for (final AnatomyTopic t in AnatomyLibrary.all) {
        final String svg = File(t.asset).readAsStringSync();
        expect(svg, contains('aria-label'), reason: t.id);
        expect(svg, contains('<title>'), reason: t.id);
        expect(t.semanticLabel.length, greaterThan(40), reason: t.id);
      }
    });

    test('anatomy ids are unique and every topic has takeaways', () {
      final Set<String> ids = AnatomyLibrary.all
          .map((AnatomyTopic t) => t.id)
          .toSet();
      expect(ids.length, AnatomyLibrary.all.length);
      for (final AnatomyTopic t in AnatomyLibrary.all) {
        expect(t.takeaways, isNotEmpty, reason: t.id);
        expect(t.body.length, greaterThan(200), reason: t.id);
      }
    });
  });

  group('pubspec asset declarations', () {
    test('the asset directories used by the app are declared', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      for (final String dir in <String>[
        'assets/animations/',
        'assets/illustrations/',
      ]) {
        expect(pubspec, contains(dir), reason: '$dir is not in pubspec.yaml');
      }
    });
  });
}
