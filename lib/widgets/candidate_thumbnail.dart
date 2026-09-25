import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/scan_pipeline.dart';

/// صورة مصغرة لمرشح. الـ Future بينحفظ حتى ما ترمش الصورة مع كل إعادة بناء.
class CandidateThumbnail extends StatefulWidget {
  const CandidateThumbnail({super.key, required this.candidate});

  final ScanCandidate candidate;

  @override
  State<CandidateThumbnail> createState() => _CandidateThumbnailState();
}

class _CandidateThumbnailState extends State<CandidateThumbnail> {
  late Future<Uint8List?> _bytes = widget.candidate.thumbnailBytes();

  @override
  void didUpdateWidget(CandidateThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.id != widget.candidate.id) {
      _bytes = widget.candidate.thumbnailBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: snap.connectionState == ConnectionState.done
                ? const Icon(Icons.broken_image_outlined)
                : null,
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
