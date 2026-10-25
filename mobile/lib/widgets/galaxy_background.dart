// Gavin - Real Hubble imagery moves quietly without rebuilding camera or guidance.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'galaxy_credit.dart';

class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});
  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground>
    with WidgetsBindingObserver {
  final _motion = ValueNotifier<double>(0);
  Timer? _timer;
  bool _reduceMotion = false, _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _updateMotion();
  }

  void _updateMotion() {
    if (_reduceMotion || !_active || !TickerMode.valuesOf(context).enabled) {
      _timer?.cancel();
      _timer = null;
    } else if (_timer == null) {
      final start = _motion.value;
      // Twenty updates per second are enough for this slow four-minute orbit.
      _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        _motion.value = (start + timer.tick / 4800) % 1;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _motion,
          child: Image.asset(
            galaxyImageAsset,
            fit: BoxFit.cover,
            cacheWidth: 1280,
            filterQuality: FilterQuality.low,
          ),
          builder: (context, value, image) {
            final angle = value * math.pi * 2;
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(12 * math.sin(angle), 18 * math.cos(angle)),
                    child: Transform.rotate(
                      angle: .025 * math.sin(angle),
                      child: Transform.scale(
                        scale: 1.12 + .025 * math.cos(angle),
                        child: image,
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xA0060816), Color(0x30060816)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
