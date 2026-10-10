import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../theme.dart';

/// Renders the small subset of Markdown the model writes: paragraphs,
/// "- " bullets, "1." lists, "#" headings, **bold**, and a "Source:" line.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.text, {super.key, this.color, this.fontSize = 15.5});
  final String text;
  final Color? color;
  final double fontSize;

  static final _bullet = RegExp(r'^\s*(?:[-*•])\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final _heading = RegExp(r'^\s*#{1,4}\s+(.*)$');
  static final _source = RegExp(r'^\s*\**\s*(source|sources|pinagmulan|batayan|basehan)\s*:\s*\**\s*(.*)$', caseSensitive: false);

  List<InlineSpan> _inline(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    final parts = s.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      // Odd parts sit between ** pairs. A trailing unmatched ** (mid-stream) stays plain.
      final bold = i.isOdd && i < parts.length - 1;
      spans.add(TextSpan(text: parts[i].replaceAll('*', ''), style: bold ? base.copyWith(fontWeight: FontWeight.w700) : null));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = TextStyle(color: color ?? cs.onSurface, fontSize: fontSize, height: 1.5);
    final children = <Widget>[];
    var gap = false;
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        gap = true;
        continue;
      }
      if (children.isNotEmpty) children.add(SizedBox(height: gap ? 10 : 4));
      gap = false;
      final b = _bullet.firstMatch(line);
      final n = _numbered.firstMatch(line);
      final h = _heading.firstMatch(line);
      final src = _source.firstMatch(line);
      if (src != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.gavel_rounded, size: 15, color: cs.primary)),
            const SizedBox(width: 6),
            Expanded(child: Text(src.group(2)!.replaceAll('*', ''), style: base.copyWith(fontSize: fontSize - 2.5, color: cs.onSurfaceVariant, height: 1.35))),
          ]),
        ));
      } else if (b != null || n != null) {
        final marker = n != null ? '${n.group(1)}.' : null;
        final body = n != null ? n.group(2)! : b!.group(1)!;
        children.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            child: marker != null
                ? Text(marker, style: base.copyWith(fontWeight: FontWeight.w700, color: cs.primary))
                : Padding(
                    padding: EdgeInsets.only(top: fontSize * 0.6, left: 4),
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                  ),
          ),
          Expanded(child: Text.rich(TextSpan(style: base, children: _inline(body, base)))),
        ]));
      } else if (h != null) {
        children.add(Text(h.group(1)!.replaceAll('*', ''), style: base.copyWith(fontWeight: FontWeight.w700, fontSize: fontSize + 1)));
      } else {
        children.add(Text.rich(TextSpan(style: base, children: _inline(line, base))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// The AI's mark: a four-point spark in the blue-violet-rose sweep. Turns while it works.
class AiSpark extends StatefulWidget {
  const AiSpark({super.key, this.size = 28, this.busy = false});
  final double size;
  final bool busy;
  @override
  State<AiSpark> createState() => _AiSparkState();
}

class _AiSparkState extends State<AiSpark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.busy) _c.repeat();
  }

  @override
  void didUpdateWidget(AiSpark old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.busy && _c.isAnimating) {
      _c.animateTo(1, duration: const Duration(milliseconds: 300)).then((_) => _c.value = 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.rotate(
            angle: Curves.easeInOutCubic.transform(_c.value) * math.pi,
            child: CustomPaint(size: Size.square(widget.size), painter: _SparkPainter()),
          ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final r = w / 2;
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: KColors.ai).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A liquid orb in the AI colours: its edge ripples and its colours turn
/// while the model works.
class LiquidOrb extends StatefulWidget {
  const LiquidOrb({super.key, this.size = 28});
  final double size;
  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(size: Size.square(widget.size), painter: _OrbPainter(_c)));
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value * 2 * math.pi;
    final c = size.center(Offset.zero);
    final r = size.width / 2 * 0.82;
    final blob = Path();
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * math.pi;
      final rr = r * (1 + 0.07 * math.sin(3 * a + v) + 0.04 * math.sin(2 * a - 2 * v));
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();
    final box = Offset.zero & size;
    canvas.drawPath(blob, Paint()..color = KColors.purple.withValues(alpha: 0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.16));
    canvas.drawPath(
      blob,
      Paint()
        ..shader = SweepGradient(
          colors: KColors.aiLoop,
          transform: GradientRotation(v),
        ).createShader(box),
    );
    // Glossy highlight, so it reads as liquid rather than a flat disc.
    final hc = c + Offset(-r * 0.3, -r * 0.35);
    canvas.drawCircle(
      hc,
      r * 0.5,
      Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: hc, radius: r * 0.5)),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => false;
}

/// Text with a bright band sweeping across it, used for "Thinking…".
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurfaceVariant;
    final hi = Theme.of(context).brightness == Brightness.dark ? Colors.white : cs.primary;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            colors: [base, base, hi, base, base],
            stops: const [0, 0.35, 0.5, 0.65, 1],
            begin: Alignment(-3 + 4 * _c.value, 0),
            end: Alignment(-1 + 4 * _c.value, 0),
          ).createShader(r),
          child: child,
        ),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}

/// Shown while the model reads the question, before its first word arrives:
/// a liquid orb, a shimmering "Thinking…", and the laws it is reading.
class ThinkingIndicator extends StatelessWidget {
  const ThinkingIndicator({super.key, required this.label, this.detail});
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A live region, so screen readers announce "Thinking…" when it appears.
    return Semantics(
      liveRegion: true,
      child: Row(children: [
        const LiquidOrb(size: 30),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ShimmerText(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Frosted-glass surface for the chat box. Content behind it blurs through;
/// while [active], a gradient ring flows around its edge.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({super.key, required this.child, this.active = false, this.radius = 30});
  final Widget child;
  final bool active;
  final double radius;
  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  void _sync() {
    final run = widget.active && !Motion.reduced(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiquidGlass old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lite = Motion.reduced(context);
    final radius = BorderRadius.circular(widget.radius);
    final fill = dark ? KColors.dGlass : KColors.lBg;
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // Opaque in lite mode; otherwise translucent, lighter at the top edge like a glass pane.
        color: lite ? fill : null,
        gradient: lite
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fill.withValues(alpha: dark ? 0.82 : 0.9), fill.withValues(alpha: dark ? 0.66 : 0.72)],
              ),
      ),
      child: widget.child,
    );
    if (!lite) body = BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: body);
    return AnimatedContainer(
      duration: Motion.d(context, 300),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: widget.active ? KColors.blue.withValues(alpha: dark ? 0.28 : 0.2) : Colors.black.withValues(alpha: dark ? 0.4 : 0.05),
            blurRadius: widget.active ? 28 : 20,
            offset: Offset(0, widget.active ? 8 : 4),
          ),
        ],
      ),
      // The ring sits on its own layer, so its animation does not repaint the chat box contents.
      child: Stack(children: [
        ClipRRect(borderRadius: radius, child: body),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _RingPainter(_c, active: widget.active, dark: dark, radius: widget.radius)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, {required this.active, required this.dark, required this.radius}) : super(repaint: t);
  final Animation<double> t;
  final bool active;
  final bool dark;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(box.deflate(0.75), Radius.circular(radius));
    if (!active) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = dark ? Colors.white.withValues(alpha: 0.16) : KColors.lPrimary.withValues(alpha: 0.22),
      );
      return;
    }
    final shader = SweepGradient(
      colors: KColors.aiLoop,
      transform: GradientRotation(t.value * 2 * math.pi),
    ).createShader(box);
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..shader = shader..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.active != active || old.dark != dark || old.radius != radius;
}

/// Illustration for the contract checker: the verified contract and the
/// swapped one, with the changed line marked.
class ContractArt extends StatelessWidget {
  const ContractArt({super.key, this.size = 120});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size * 0.86), painter: _ContractArtPainter(Theme.of(context).brightness == Brightness.dark));
}

class _ContractArtPainter extends CustomPainter {
  _ContractArtPainter(this.dark);
  final bool dark;

  void _sheet(Canvas canvas, Rect r, double angle, {required bool changed}) {
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(angle);
    canvas.translate(-r.center.dx, -r.center.dy);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.08));
    canvas.drawRRect(rr.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawRRect(rr, Paint()..color = Colors.white);
    final line = Paint()
      ..color = const Color(0xFFC2D3F5)
      ..strokeWidth = r.width * 0.06
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = r.top + r.height * (0.2 + i * 0.14);
      final end = r.left + r.width * (i == 4 ? 0.55 : 0.82);
      if (changed && i == 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(r.left + r.width * 0.12, y - r.width * 0.07, r.left + r.width * 0.88, y + r.width * 0.07), const Radius.circular(4)),
          Paint()..color = const Color(0xFFF28B82).withValues(alpha: 0.45),
        );
        canvas.drawLine(Offset(r.left + r.width * 0.18, y), Offset(end, y), Paint()..color = const Color(0xFFD93025)..strokeWidth = r.width * 0.06..strokeCap = StrokeCap.round);
      } else {
        canvas.drawLine(Offset(r.left + r.width * 0.18, y), Offset(end, y), line);
      }
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _sheet(canvas, Rect.fromLTWH(w * 0.04, h * 0.08, w * 0.5, h * 0.8), -0.12, changed: false);
    _sheet(canvas, Rect.fromLTWH(w * 0.42, h * 0.06, w * 0.5, h * 0.8), 0.1, changed: true);
    // Magnifier over the changed line.
    final c = Offset(w * 0.72, h * 0.52);
    canvas.drawCircle(c, w * 0.15, Paint()..color = Colors.white.withValues(alpha: 0.25));
    canvas.drawCircle(c, w * 0.15, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = w * 0.035);
    canvas.drawLine(c + Offset(w * 0.11, w * 0.11), c + Offset(w * 0.22, w * 0.22), Paint()..color = Colors.white..strokeWidth = w * 0.05..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _ContractArtPainter old) => old.dark != dark;
}

/// Big greeting with the AI colour sweep across the text, as in Google's AI apps.
class GradientGreeting extends StatelessWidget {
  const GradientGreeting(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => const LinearGradient(colors: KColors.ai).createShader(r),
      child: Text(text, style: style),
    );
  }
}

/// Short label for whether the reply came from the model or the built-in guide.
String answeredBy(BuildContext context, bool ai) =>
    ai ? tr(context, 'On-device AI · offline', 'AI sa phone · offline') : tr(context, 'Built-in legal guide · offline', 'Built-in na legal guide · offline');
