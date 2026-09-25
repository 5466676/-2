import 'package:flutter/material.dart';

import '../services/scan_pipeline.dart';
import 'candidate_thumbnail.dart';

/// شبكة النتائج: ضغطة = تبديل الاختيار، ضغطة مطوّلة = عرض كامل.
class ResultsGrid extends StatelessWidget {
  const ResultsGrid({
    super.key,
    required this.matches,
    required this.isSelected,
    required this.onToggle,
    required this.onOpen,
  });

  final List<ScanMatch> matches;
  final bool Function(String id) isSelected;
  final void Function(String id) onToggle;
  final void Function(ScanMatch match) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final m = matches[i];
        final id = m.candidate.id;
        return _Tile(
          key: ValueKey(id),
          match: m,
          selected: isSelected(id),
          onTap: () => onToggle(id),
          onLongPress: () => onOpen(m),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.match,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final ScanMatch match;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selected ? 1 : 0.4,
              child: CandidateThumbnail(candidate: match.candidate),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black38)],
              ),
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : Colors.black45,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 4,
            start: 4,
            child: _Badge(match: match),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.match});

  final ScanMatch match;

  @override
  Widget build(BuildContext context) {
    final text = match.reason == MatchReason.learned
        ? 'متعلَّمة'
        : '${(match.score * 100).round()}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
