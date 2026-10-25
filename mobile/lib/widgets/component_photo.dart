// Gavin - Zoom the selected mounting area without moving its numbered markers.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/fastener_map.dart';
import '../services/component_snapshot.dart';

class ComponentPhoto extends StatefulWidget {
  const ComponentPhoto({
    super.key,
    required this.snapshot,
    required this.region,
    this.marks = const [],
    this.activeMark,
    this.onMark,
  });
  final ComponentSnapshot snapshot;
  final Rect region;
  final List<FastenerMark> marks;
  final int? activeMark;
  final ValueChanged<Offset>? onMark;
  @override
  State<ComponentPhoto> createState() => _ComponentPhotoState();
}

class _ComponentPhotoState extends State<ComponentPhoto> {
  ui.Image? _image;
  bool _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final image = await widget.snapshot.render();
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didUpdateWidget(ComponentPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot == widget.snapshot) return;
    _image?.dispose();
    _image = null;
    _failed = false;
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return Center(
        child: _failed
            ? const Text(
                'Photo unavailable. Return to the live camera and retry.',
              )
            : const CircularProgressIndicator(
                semanticsLabel: 'Preparing component photo',
              ),
      );
    }
    final region = widget.region;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: AspectRatio(
          aspectRatio:
              image.width / image.height * region.width / region.height,
          child: LayoutBuilder(
            builder: (context, size) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onMark == null
                  ? null
                  : (tap) => widget.onMark!(
                      Offset(
                        (tap.localPosition.dx / size.maxWidth).clamp(0, 1),
                        (tap.localPosition.dy / size.maxHeight).clamp(0, 1),
                      ),
                    ),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: -region.left / region.width * size.maxWidth,
                      top: -region.top / region.height * size.maxHeight,
                      width: size.maxWidth / region.width,
                      height: size.maxHeight / region.height,
                      child: RawImage(image: image, fit: BoxFit.fill),
                    ),
                    for (var i = 0; i < widget.marks.length; i++)
                      Positioned(
                        left: widget.marks[i].position.dx * size.maxWidth - 14,
                        top: widget.marks[i].position.dy * size.maxHeight - 14,
                        child: Semantics(
                          label: widget.marks[i].name(i),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: widget.activeMark == i
                                ? const Color(0xFFB6A5FF)
                                : const Color(0xFF87DDEB),
                            foregroundColor: Colors.black,
                            child: Text(
                              '${i + 1}',
                              textScaler: TextScaler.noScaling,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
