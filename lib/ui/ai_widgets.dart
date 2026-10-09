import 'dart:math' as math;

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

/// Gemini-style placeholder lines with a moving colour sweep, shown while
/// the model reads the question and before its first word arrives.
class ThinkingShimmer extends StatefulWidget {
  const ThinkingShimmer({super.key});
  @override
  State<ThinkingShimmer> createState() => _ThinkingShimmerState();
}

class _ThinkingShimmerState extends State<ThinkingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A3A5C) : const Color(0xFFD3E3FD);
    final hi = dark ? const Color(0xFF6A5A9C) : const Color(0xFFE8DEF8);
    Widget line(double f) => FractionallySizedBox(
          widthFactor: f,
          alignment: Alignment.centerLeft,
          child: Container(height: 13, margin: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99))),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            colors: [base, hi, cs.surface.withValues(alpha: 0.6), base],
            stops: const [0, 0.35, 0.5, 1],
            begin: Alignment(-3 + 4 * _c.value, 0),
            end: Alignment(-1 + 4 * _c.value, 0),
          ).createShader(r),
          child: child,
        ),
        child: Column(children: [line(1), line(0.92), line(0.6)]),
      ),
    ]);
  }
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
