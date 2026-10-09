import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_state.dart';
import '../theme.dart';
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

  void _tap(String d) {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length >= 4) {
      final ok = AppScope.read(context).checkPin(_pin);
      if (ok) {
        widget.onUnlocked();
      } else if (_pin.length == 6) {
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _shake++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          const KLogo(size: 72),
          const SizedBox(height: 16),
          Text(tr(context, 'Enter your PIN', 'Ilagay ang PIN mo'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _PinDots(length: _pin.length).animate(key: ValueKey(_shake)).shakeX(hz: 6, amount: _shake == 0 ? 0 : 8, duration: 420.ms),
          const Spacer(),
          _Keypad(onDigit: _tap, onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length});
  final int length;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 6; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? cs.primary : Colors.transparent,
            border: Border.all(color: i < length ? cs.primary : cs.outline, width: 2),
          ),
        ),
    ]);
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack});
  final void Function(String) onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Pressable(
          onTap: onTap ?? () => onDigit(label),
          scale: 0.9,
          child: Container(
            width: 76,
            height: 76,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: label.isEmpty && icon == null ? Colors.transparent : KTokens.of(context).surfaceAlt),
            alignment: Alignment.center,
            child: icon != null ? Icon(icon, color: cs.onSurface) : Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          ),
        );
    return Column(children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key('', onTap: () {}),
        key('0'),
        key('', icon: Icons.backspace_rounded, onTap: onBack),
      ]),
    ]);
  }
}

/// Two-step PIN entry (enter, confirm). Returns true when a PIN was set.
Future<bool> showPinSetup(BuildContext context) async {
  String? first;
  final s = AppScope.read(context);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, setSt) {
      var pin = '';
      return _PinEntrySheet(
        title: tr(c, 'Choose a 4–6 digit PIN', 'Pumili ng 4–6 na digit na PIN'),
        onDone: (p) {
          if (first == null) {
            first = p;
            return false;
          }
          if (first == p) {
            s.setPin(p);
            Navigator.pop(c, true);
            return true;
          }
          first = null;
          pin = '';
          return false;
        },
        confirmTitle: tr(c, 'Enter it again', 'Ilagay ulit'),
        initial: pin,
      );
    }),
  );
  return ok ?? false;
}

class _PinEntrySheet extends StatefulWidget {
  const _PinEntrySheet({required this.title, required this.confirmTitle, required this.onDone, required this.initial});
  final String title;
  final String confirmTitle;
  final bool Function(String) onDone;
  final String initial;
  @override
  State<_PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<_PinEntrySheet> {
  String _pin = '';
  bool _confirm = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: Motion.d(context, 250),
            child: Text(_confirm ? widget.confirmTitle : widget.title, key: ValueKey(_confirm), style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 18),
          _PinDots(length: _pin.length),
          const SizedBox(height: 10),
          Opacity(
            opacity: _pin.length >= 4 ? 1 : 0.4,
            child: FilledButton(
              onPressed: _pin.length >= 4
                  ? () {
                      final done = widget.onDone(_pin);
                      if (!done) {
                        setState(() {
                          _confirm = !_confirm;
                          _pin = '';
                        });
                      }
                    }
                  : null,
              child: Text(tr(context, 'OK', 'OK')),
            ),
          ),
          _Keypad(
            onDigit: (d) {
              if (_pin.length < 6) setState(() => _pin += d);
            },
            onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
          ),
        ]),
      ),
    );
  }
}
