import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/services/hash_store.dart';

void main() {
  test('matches exact and near hashes within the distance', () async {
    final store = DecisionStore(maxDistance: 2);
    await store.record(Decision.deleted, [0x00FF]);

    expect(store.matches(0x00FF, Decision.deleted), isTrue);
    expect(store.matches(0x00FC, Decision.deleted), isTrue); // فرق بتين
    expect(store.matches(0x00F0, Decision.deleted), isFalse); // فرق 4
    expect(store.matches(0x00FF, Decision.kept), isFalse);
  });

  test('newer decision overrides the older one', () async {
    final store = DecisionStore();
    await store.record(Decision.kept, [42]);
    await store.record(Decision.deleted, [42]);

    expect(store.count(Decision.kept), 0);
    expect(store.count(Decision.deleted), 1);
  });

  test('clear forgets everything', () async {
    final store = DecisionStore();
    await store.record(Decision.kept, [1, 2]);
    await store.record(Decision.deleted, [3]);
    await store.clear();

    expect(store.count(Decision.kept), 0);
    expect(store.count(Decision.deleted), 0);
  });
}
