import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'theme.dart';
import 'ui/chat.dart';
import 'ui/lock.dart';
import 'ui/onboarding.dart';

class KontrataApp extends StatelessWidget {
  const KontrataApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final s = AppScope.of(context);
        return MaterialApp(
          title: 'Kontrata',
          debugShowCheckedModeBanner: false,
          theme: KTheme.light(),
          darkTheme: KTheme.dark(),
          themeMode: s.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
              // Respect the phone's text size, but cap it so layouts stay usable.
              child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.35, child: child!),
            );
          },
          home: const _Root(),
        );
      }),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock whenever the app goes to the background.
    if (state == AppLifecycleState.paused && AppScope.read(context).hasPin) {
      setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final Widget child;
    if (!s.onboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (s.hasPin && !_unlocked) {
      child = LockScreen(key: const ValueKey('lock'), onUnlocked: () => setState(() => _unlocked = true));
    } else {
      child = const ChatScreen(key: ValueKey('chat'));
    }
    return AnimatedSwitcher(
      duration: Motion.d(context, 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}
