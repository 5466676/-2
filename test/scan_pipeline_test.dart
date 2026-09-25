import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/services/hash_store.dart';
import 'package:greeting_cleaner/services/scan_pipeline.dart';

/// مرشح وهمي: أول بايت بالصورة المصغرة = البصمة، والمسار = المعرّف.
class _Candidate implements ScanCandidate {
  _Candidate(this.id, this.hash, {this.hasPath = true});

  @override
  final String id;
  final int hash;
  final bool hasPath;

  @override
  Future<Uint8List?> thumbnailBytes() async => Uint8List.fromList([hash]);

  @override
  Future<String?> filePath() async => hasPath ? id : null;
}

class _Faces implements FaceChecker {
  _Faces(this.withFaces);

  final Set<String> withFaces;
  final checked = <String>[];

  @override
  Future<bool> hasFace(String path) async {
    checked.add(path);
    return withFaces.contains(path);
  }
}

class _Scorer implements GreetingScorer {
  _Scorer(this.scores, {this.isAvailable = true});

  final Map<int, double> scores;
  final scored = <int>[];

  @override
  final bool isAvailable;

  @override
  Future<double?> score(Uint8List imageBytes) async {
    scored.add(imageBytes.first);
    return scores[imageBytes.first];
  }
}

Future<int?> _firstByte(Uint8List b) async => b.first;

void main() {
  late DecisionStore store;

  setUp(() => store = DecisionStore(maxDistance: 0));

  Future<List<ScanProgress>> run(
    List<ScanCandidate> items, {
    _Faces? faces,
    _Scorer? scorer,
  }) {
    final pipeline = ScanPipeline(
      store: store,
      faces: faces ?? _Faces({}),
      scorer: scorer ?? _Scorer({}),
      threshold: 0.7,
      hasher: _firstByte,
    );
    return pipeline.run(items).toList();
  }

  test('model scores above the threshold become matches', () async {
    final events = await run(
      [_Candidate('a', 1), _Candidate('b', 2), _Candidate('c', 3)],
      scorer: _Scorer({1: 0.9, 2: 0.5, 3: 0.7}),
    );

    final matches = events.map((e) => e.match).nonNulls.toList();
    expect(matches.map((m) => m.candidate.id), ['a', 'c']);
    expect(matches.every((m) => m.reason == MatchReason.model), isTrue);
    expect(events.last.stats.processed, 3);
    expect(events.last.stats.model, 2);
  });

  test('kept list is checked first and skips everything else', () async {
    await store.record(Decision.kept, [1]);
    final faces = _Faces({});
    final scorer = _Scorer({1: 0.99});

    final events =
        await run([_Candidate('a', 1)], faces: faces, scorer: scorer);

    expect(events.single.match, isNull);
    expect(events.single.stats.skippedKept, 1);
    expect(faces.checked, isEmpty);
    expect(scorer.scored, isEmpty);
  });

  test('faces are protected even when learned as deleted', () async {
    await store.record(Decision.deleted, [1]);
    final scorer = _Scorer({1: 0.99});

    final events = await run(
      [_Candidate('a', 1)],
      faces: _Faces({'a'}),
      scorer: scorer,
    );

    expect(events.single.match, isNull);
    expect(events.single.stats.protectedFaces, 1);
    expect(scorer.scored, isEmpty);
  });

  test('missing file path is treated as protected', () async {
    final events = await run(
      [_Candidate('a', 1, hasPath: false)],
      scorer: _Scorer({1: 0.99}),
    );
    expect(events.single.match, isNull);
    expect(events.single.stats.protectedFaces, 1);
  });

  test('learned deletions match without calling the model', () async {
    await store.record(Decision.deleted, [5]);
    final scorer = _Scorer({5: 0.1});

    final events = await run([_Candidate('a', 5)], scorer: scorer);

    expect(events.single.match?.reason, MatchReason.learned);
    expect(scorer.scored, isEmpty);
  });

  test('without a model only learned deletions match', () async {
    await store.record(Decision.deleted, [5]);
    final scorer = _Scorer({6: 0.99}, isAvailable: false);

    final events = await run(
      [_Candidate('a', 5), _Candidate('b', 6)],
      scorer: scorer,
    );

    expect(events.map((e) => e.match?.candidate.id).nonNulls, ['a']);
    expect(scorer.scored, isEmpty);
  });

  test('a failing candidate is counted and the scan continues', () async {
    final pipeline = ScanPipeline(
      store: store,
      faces: _Faces({}),
      scorer: _Scorer({2: 0.9}),
      hasher: (b) async => b.first == 1 ? throw StateError('boom') : b.first,
    );

    final events =
        await pipeline.run([_Candidate('a', 1), _Candidate('b', 2)]).toList();

    expect(events.last.stats.failed, 1);
    expect(events.last.match?.candidate.id, 'b');
  });
}
