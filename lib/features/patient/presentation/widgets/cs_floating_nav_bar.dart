import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

/// Navigation item data for [CSFloatingNavBar].
class CSNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Optional SVG asset path (e.g. 'assets/icons/ic_profile.svg').
  /// When provided, the SVG is rendered instead of [icon].
  final String? svgAsset;

  /// Optional SVG asset path for the active state.
  /// Falls back to [svgAsset] if not provided.
  final String? activeSvgAsset;

  const CSNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.svgAsset,
    this.activeSvgAsset,
  });
}

/// CareSync's premium liquid-floating bottom navigation bar.
///
/// Inspired by the MHBottomNavBar from Mothers-Hut.
/// Features:
/// - Glassmorphism frosted-glass background
/// - Liquid pill that stretches and animates between active tabs
/// - Active item expands to show icon + label; inactive shows icon only
/// - Haptic feedback on tap
class CSFloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final List<CSNavItem> items;
  final void Function(int) onTap;

  const CSFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  State<CSFloatingNavBar> createState() => _CSFloatingNavBarState();
}

class _CSFloatingNavBarState extends State<CSFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  int _prevSlot = 0;
  int _currentSlot = 0;

  // Widths for active/inactive slots
  static const double _activeW = 112.0;
  static const double _inactiveW = 52.0;
  static const double _hPad = 10.0;
  static const double _barH = 64.0;
  static const double _pillH = 44.0;

  double _itemLeft(int idx, int activeIdx) {
    double left = _hPad;
    for (int i = 0; i < idx; i++) {
      left += (i == activeIdx) ? _activeW : _inactiveW;
    }
    return left;
  }

  double _itemWidth(int idx, int activeIdx) =>
      idx == activeIdx ? _activeW : _inactiveW;

  @override
  void initState() {
    super.initState();
    _prevSlot = widget.selectedIndex;
    _currentSlot = _prevSlot;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(CSFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _prevSlot = oldWidget.selectedIndex;
      _currentSlot = widget.selectedIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalW =
        _activeW + (_inactiveW * (widget.items.length - 1)) + (_hPad * 2);

    // CareSync brand palette
    const Color pillBg = Color(0xFF121212); // Dark charcoal pill
    const Color activeColor = Colors.white;
    const Color inactiveColor = Color(0xFF9BA3AF);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: SizedBox(
            width: totalW,
            height: _barH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Glass Background ────────────────────────────────────
                const Positioned.fill(child: _GlassBackground()),

                // ── Liquid Indicator Pill ───────────────────────────────
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final t = _anim.value;

                    final prevCenter =
                        _itemLeft(_prevSlot, _prevSlot) + _activeW / 2;
                    final targetCenter =
                        _itemLeft(_currentSlot, _currentSlot) + _activeW / 2;
                    final curCenter =
                        prevCenter + (targetCenter - prevCenter) * t;

                    final dist = (targetCenter - prevCenter).abs();
                    final stretch = dist * 0.26 * math.sin(t * math.pi);
                    final shrink = (stretch * 0.10).clamp(0.0, 5.0);

                    final pW = _activeW + stretch;
                    final pH = _pillH - shrink;
                    final pLeft = curCenter - pW / 2;

                    return Positioned(
                      left: pLeft,
                      top: (_barH - pH) / 2,
                      child: Container(
                        width: pW,
                        height: pH,
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // ── Tab Items ───────────────────────────────────────────
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final t = _anim.value;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(widget.items.length, (idx) {
                        final item = widget.items[idx];
                        final isActive = widget.selectedIndex == idx;

                        final leftStart = _itemLeft(idx, _prevSlot);
                        final leftEnd = _itemLeft(idx, _currentSlot);
                        final itemLeft = leftStart + (leftEnd - leftStart) * t;

                        final wStart = _itemWidth(idx, _prevSlot);
                        final wEnd = _itemWidth(idx, _currentSlot);
                        final itemW = wStart + (wEnd - wStart) * t;

                        double opacity = 0.0;
                        if (idx == _currentSlot) {
                          opacity = t;
                        } else if (idx == _prevSlot) {
                          opacity = 1.0 - t;
                        }

                        final Color itemColor = Color.lerp(
                          inactiveColor,
                          activeColor,
                          idx == _currentSlot
                              ? t
                              : (idx == _prevSlot ? (1.0 - t) : 0.0),
                        )!;

                        return Positioned(
                          left: itemLeft,
                          top: (_barH - _pillH) / 2,
                          width: itemW,
                          height: _pillH,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onTap(idx);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Icon always occupies a fixed slot
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                        child: _buildIcon(
                                            item, isActive, itemColor),
                                      ),
                                    ),
                                    ClipRect(
                                      child: SizedBox(
                                        width:
                                            (itemW - 46.0).clamp(0.0, 72.0),
                                        child: Opacity(
                                          opacity: opacity.clamp(0.0, 1.0),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 6),
                                                Text(
                                                  item.label,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: activeColor,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: bottomInset > 0 ? bottomInset : 16),
      ],
    );
  }
}

/// Frosted-glass pill container for the nav bar background.
class _GlassBackground extends StatelessWidget {
  const _GlassBackground();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.72),
                Colors.white.withOpacity(0.42),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders either an SVG asset or an [IconData] icon depending on [item] config.
Widget _buildIcon(CSNavItem item, bool isActive, Color color) {
  final String? assetPath =
      isActive ? (item.activeSvgAsset ?? item.svgAsset) : item.svgAsset;

  if (assetPath != null) {
    return SvgPicture.asset(
      assetPath,
      width: 19,
      height: 19,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  final IconData iconData = isActive ? item.activeIcon : item.icon;
  return Icon(iconData, size: 19, color: color);
}

/// Default CareSync navigation items.
const kCSNavItems = [
  CSNavItem(
    icon: Iconsax.home,
    activeIcon: Iconsax.home,        // Linear variant — renders reliably; color distinguishes active
    label: 'Home',
  ),
  CSNavItem(
    icon: Iconsax.document_text,
    activeIcon: Iconsax.document_text, // Same, color distinguishes active
    label: 'Records',
  ),
  CSNavItem(
    icon: Iconsax.user,              // SVG takes over when rendered
    activeIcon: Iconsax.user,
    label: 'Profile',
    svgAsset: 'assets/icons/ic_profile.svg',
    activeSvgAsset: 'assets/icons/ic_profile.svg',
  ),
  CSNavItem(
    icon: Iconsax.radar_1,
    activeIcon: Iconsax.radar_1,
    label: 'Emergency',
    svgAsset: 'assets/icons/ic_emergency.svg',
    activeSvgAsset: 'assets/icons/ic_emergency.svg',
  ),
];
