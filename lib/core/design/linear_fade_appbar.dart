import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connectivity_service.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'circular_icon_button.dart';

/// A gradient-fade "app bar" overlay (scaffold → transparent) instead of a
/// Material [AppBar]. Sits above the body; content scrolls beneath it.
///
/// Layout: `[leading] Spacer [title] Spacer [actions]`, with a 44-wide slot on
/// each side so the title stays optically centred.
class LinearFadeAppBar extends StatelessWidget {
  const LinearFadeAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.automaticBack = true,
  });

  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool automaticBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = t.scaffold;

    Widget? lead = leading;
    if (lead == null && automaticBack && Navigator.of(context).canPop()) {
      lead = CircularIconButton(
        icon: Iconsax.arrow_left_2,
        onTap: () => Navigator.of(context).maybePop(),
      );
    }

    final trailing = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) trailing.add(const SizedBox(width: 8));
      trailing.add(actions[i]);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s, s, s.withValues(alpha: 0.8), s.withValues(alpha: 0)],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSpacing.appBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.iconButton,
                  child: lead ?? const SizedBox.shrink(),
                ),
                if (title != null)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        title!,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: t.appBarTitle,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing.isEmpty)
                  const SizedBox(width: AppSpacing.iconButton)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drop-in scaffold that pairs a scroll [body] with a [LinearFadeAppBar]
/// overlay and offsets the body below the bar (status bar + 72), so migrating
/// a `Scaffold(appBar: AppBar(...))` screen is a one-line swap.
class CSScaffold extends ConsumerWidget {
  const CSScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions = const [],
    this.automaticBack = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool automaticBack;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final topInset =
        MediaQuery.of(context).padding.top + AppSpacing.appBarHeight;

    final connectivity = ref.watch(connectivityStatusProvider).valueOrNull;
    final isOffline = connectivity == ConnectivityStatus.offline;

    return Scaffold(
      backgroundColor: backgroundColor ?? t.scaffold,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            padding: EdgeInsets.only(top: topInset + (isOffline ? 28.0 : 0.0)),
            child: body,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearFadeAppBar(
              title: title,
              leading: leading,
              actions: actions,
              automaticBack: automaticBack,
            ),
          ),
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              height: isOffline ? 28.0 : 0.0,
              child: ClipRect(
                child:
                    isOffline
                        ? Container(
                          color: t.error,
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Offline Mode — Some actions are disabled',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
