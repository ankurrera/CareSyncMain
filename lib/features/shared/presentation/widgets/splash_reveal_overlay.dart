import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flipped to true by [SplashScreen] once it has navigated to the first real
/// destination, so the overlay can zoom-reveal the screen already beneath it.
final splashRevealProvider = StateProvider<bool>((ref) => false);

/// Full-screen launch overlay that sits above the router (see [CareSync]).
///
/// It mirrors the splash route (logo centered on the scaffold colour), then —
/// once [splashRevealProvider] fires — the background fades away while the
/// logo scales up explosively past the screen edges, revealing the app
/// underneath through the glyph's transparent gaps. After the animation the
/// widget removes itself for the rest of the session.
class SplashRevealOverlay extends ConsumerStatefulWidget {
  const SplashRevealOverlay({super.key});

  @override
  ConsumerState<SplashRevealOverlay> createState() =>
      _SplashRevealOverlayState();
}

class _SplashRevealOverlayState extends ConsumerState<SplashRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _backgroundOpacity;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _done = true);
      }
    });

    // Brief anticipation dip, then the accelerating zoom past the edges.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 26.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 85,
      ),
    ]).animate(_controller);
    _backgroundOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.65, curve: Curves.easeInOut),
      ),
    );

    // Covers a hot-restart where the reveal already happened.
    if (ref.read(splashRevealProvider)) {
      _done = true;
    }

    // Safety-net: if splashRevealProvider is never set to true within 6 seconds
    // (e.g. due to a race condition between the router and SplashScreen),
    // force the reveal so the user is never permanently stuck.
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted || _done || _controller.isAnimating) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(splashRevealProvider, (previous, next) {
      if (next && !_done && !_controller.isAnimating) {
        _controller.forward();
      }
    });

    if (_done) return const SizedBox.shrink();

    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _backgroundOpacity.value,
            child: Transform.scale(
              scale: _scale.value,
              filterQuality: FilterQuality.medium,
              child: SizedBox.expand(
                child: Image.asset(
                  'assets/Splash_Screen.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
