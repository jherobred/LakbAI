import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_state.dart';
import 'widgets.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  int _shake = 0;
  bool _wrong = false;

  void _fail() {
    HapticFeedback.heavyImpact();
    setState(() {
      _pin = '';
      _shake++;
      _wrong = true;
    });
  }

  void _tap(String d) {
    final s = AppScope.read(context);
    final len = s.pinLength;
    if (_pin.length >= (len ?? 6)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (len != null) {
      // Known length: check exactly once, when the last dot fills.
      if (_pin.length == len) s.checkPin(_pin) ? widget.onUnlocked() : _fail();
    } else if (_pin.length >= 4) {
      // Older PINs (saved before the length was stored) can be 4–6 digits.
      if (s.checkPin(_pin)) {
        widget.onUnlocked();
      } else if (_pin.length == 6) {
        _fail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final len = AppScope.of(context).pinLength;
    return BackToExit(
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            const Spacer(),
            const KLogo(size: 64),
            const SizedBox(height: 20),
            Text(tr(context, 'Enter your PIN', 'Ilagay ang PIN mo'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: _wrong ? 1 : 0,
              duration: Motion.d(context, 200),
              child: Text(tr(context, 'Wrong PIN. Try again.', 'Mali ang PIN. Subukan ulit.'), style: TextStyle(color: cs.error)),
            ),
            const SizedBox(height: 16),
            PinDots(length: _pin.length, slots: len ?? (_pin.length < 4 ? 4 : _pin.length))
                .animate(key: ValueKey(_shake))
                .shakeX(hz: 6, amount: _shake == 0 ? 0 : 8, duration: 420.ms),
            const Spacer(),
            PinKeypad(onDigit: _tap, onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

/// One dot per PIN digit. [slots] is how many dots to draw.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.slots});
  final int length;
  final int slots;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 18,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < slots; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: i < length ? 16 : 12,
            height: i < length ? 16 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? cs.primary : cs.surfaceContainerHighest,
            ),
          ),
      ]),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onDigit, required this.onBack});
  final void Function(String) onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      final blank = label.isEmpty && icon == null;
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: blank ? Colors.transparent : cs.surfaceContainer,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: blank
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    (onTap ?? () => onDigit(label))();
                  },
            child: SizedBox.square(
              dimension: 76,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: cs.onSurfaceVariant)
                    : Text(label, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: cs.onSurface)),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key(''),
        key('0'),
        key('', icon: Icons.backspace_outlined, onTap: onBack),
      ]),
    ]);
  }
}

/// Two-step PIN entry (enter, confirm). Returns true when a PIN was set.
Future<bool> showPinSetup(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => const _PinSetupSheet(),
  );
  return ok ?? false;
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();
  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  String _pin = '';
  String? _first;
  bool _mismatch = false;
  int _shake = 0;

  void _digit(String d) {
    final max = _first?.length ?? 6;
    if (_pin.length >= max) return;
    setState(() {
      _pin += d;
      _mismatch = false;
    });
    // Confirming: the length is known, so check as soon as it is complete.
    if (_first != null && _pin.length == _first!.length) _confirm();
  }

  void _next() {
    HapticFeedback.lightImpact();
    setState(() {
      _first = _pin;
      _pin = '';
    });
  }

  void _confirm() {
    if (_pin == _first) {
      AppScope.read(context).setPin(_pin);
      Navigator.pop(context, true);
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _first = null;
      _pin = '';
      _mismatch = true;
      _shake++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final confirming = _first != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: Motion.d(context, 250),
            child: Text(
              confirming ? tr(context, 'Enter it again', 'Ilagay ulit') : tr(context, 'Choose a 4–6 digit PIN', 'Pumili ng 4–6 na digit na PIN'),
              key: ValueKey(confirming),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _mismatch ? tr(context, "PINs didn't match. Start again.", 'Hindi nagtugma. Ulitin.') : ' ',
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
          const SizedBox(height: 12),
          PinDots(length: _pin.length, slots: _first?.length ?? (_pin.length < 4 ? 4 : _pin.length))
              .animate(key: ValueKey(_shake))
              .shakeX(hz: 6, amount: _shake == 0 ? 0 : 8, duration: 420.ms),
          const SizedBox(height: 14),
          if (!confirming)
            FilledButton(
              onPressed: _pin.length >= 4 ? _next : null,
              child: Text(tr(context, 'Next', 'Susunod')),
            )
          else
            const SizedBox(height: 52),
          const SizedBox(height: 6),
          PinKeypad(
            onDigit: _digit,
            onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
          ),
        ]),
      ),
    );
  }
}
