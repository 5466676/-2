import 'dart:io';

import 'package:flutter/material.dart';

import '../services/gallery_service.dart';
import '../services/scan_pipeline.dart';
import 'candidate_thumbnail.dart';

/// عارض الصورة بالحجم الكامل مع تكبير. زر الصح بيغيّر اختيارها.
class FullImageViewer extends StatefulWidget {
  const FullImageViewer({
    super.key,
    required this.candidate,
    required this.isSelected,
    required this.onToggle,
  });

  final ScanCandidate candidate;
  final bool Function() isSelected;
  final VoidCallback onToggle;

  static Future<void> open(
    BuildContext context, {
    required ScanCandidate candidate,
    required bool Function() isSelected,
    required VoidCallback onToggle,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullImageViewer(
          candidate: candidate,
          isSelected: isSelected,
          onToggle: onToggle,
        ),
      ),
    );
  }

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final Future<File?> _file = switch (widget.candidate) {
    final GalleryImage g => g.file(),
    _ => Future.value(null),
  };

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              widget.onToggle();
              setState(() {});
            },
            icon: Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            label: Text(selected ? 'رح تنمسح' : 'محتفظ فيها'),
          ),
        ],
      ),
      body: FutureBuilder<File?>(
        future: _file,
        builder: (context, snap) {
          final file = snap.data;
          final Widget image = file != null
              ? Image.file(file, fit: BoxFit.contain)
              : CandidateThumbnail(candidate: widget.candidate);
          return InteractiveViewer(
            maxScale: 5,
            child: Center(child: image),
          );
        },
      ),
    );
  }
}
