import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../ai/ai_service.dart';
import '../core/app_state.dart';
import '../theme.dart';

enum VoicePhase { idle, recording, transcribing, error }

/// Records speech and turns it into text with Whisper, on the phone.
/// Stops by itself after a pause once the worker has spoken.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({this.silenceToStop = const Duration(milliseconds: 1600), this.onAutoStop});

  final Duration silenceToStop;
  final VoidCallback? onAutoStop;

  final _rec = AudioRecorder();
  VoicePhase phase = VoicePhase.idle;
  final List<double> levels = List.filled(36, 0.04);
  int seconds = 0;
  String? error;

  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  String? _path;
  bool _heard = false;
  DateTime _lastLoud = DateTime.now();
  bool _disposed = false;

  static const maxSeconds = 29;

  void _set(VoidCallback f) {
    f();
    if (!_disposed) notifyListeners();
  }

  /// Returns false when the microphone could not start; [error] says why.
  Future<bool> start({required String permissionMessage}) async {
    if (phase == VoicePhase.recording) return true;
    try {
      if (!await _rec.hasPermission()) {
        _set(() {
          phase = VoicePhase.error;
          error = permissionMessage;
        });
        return false;
      }
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          // Cleaner input for Whisper in noisy rooms.
          noiseSuppress: true,
          echoCancel: true,
          autoGain: true,
        ),
        path: _path!,
      );
    } catch (e) {
      _set(() {
        phase = VoicePhase.error;
        error = '$e';
      });
      return false;
    }
    HapticFeedback.mediumImpact();
    _heard = false;
    _lastLoud = DateTime.now();
    seconds = 0;
    levels.fillRange(0, levels.length, 0.04);
    _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 70)).listen((a) {
      // dBFS (about -60..0) to 0..1
      final v = ((a.current + 55) / 50).clamp(0.04, 1.0);
      final now = DateTime.now();
      if (a.current > -36) {
        _heard = true;
        _lastLoud = now;
      }
      _set(() {
        levels.removeAt(0);
        levels.add(v);
      });
      if (_heard && now.difference(_lastLoud) > silenceToStop) onAutoStop?.call();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _set(() => seconds++);
      if (seconds >= maxSeconds) onAutoStop?.call();
    });
    _set(() => phase = VoicePhase.recording);
    return true;
  }

  /// Stops recording and returns the transcript ('' when nothing was heard).
  Future<String> finish(String language) async {
    if (phase != VoicePhase.recording) return '';
    _set(() => phase = VoicePhase.transcribing);
    _timer?.cancel();
    await _ampSub?.cancel();
    final path = await _rec.stop() ?? _path;
    try {
      final wav = await File(path!).readAsBytes();
      final pcm = pcmFromWav(wav);
      // Under half a second of audio is a mis-tap, not speech.
      if (pcm.length < 16000) {
        _set(() => phase = VoicePhase.idle);
        return '';
      }
      final text = await AiService.instance.transcribe(pcm, language);
      _set(() => phase = VoicePhase.idle);
      return text;
    } catch (e) {
      _set(() {
        phase = VoicePhase.error;
        error = '$e';
      });
      return '';
    } finally {
      try {
        await File(path!).delete();
      } catch (_) {}
    }
  }

  Future<void> cancel() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    try {
      await _rec.cancel();
    } catch (_) {}
    _set(() => phase = VoicePhase.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _ampSub?.cancel();
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }
}

/// Live sound bars in the AI colours.
class VoiceWave extends StatelessWidget {
  const VoiceWave({super.key, required this.levels, required this.active, this.height = 40, this.barWidth = 4});
  final List<double> levels;
  final bool active;
  final double height;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < levels.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: EdgeInsets.symmetric(horizontal: barWidth * 0.4),
            width: barWidth,
            height: active ? 4 + (height - 4) * levels[i] * (0.55 + 0.45 * math.sin(i / 2.2).abs()) : 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KColors.ai[i * 3 ~/ levels.length], KColors.ai[math.min(2, i * 3 ~/ levels.length + 1)]],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ]),
    );
  }
}

/// Switches the microphone between Filipino and English.
class VoiceLangToggle extends StatelessWidget {
  const VoiceLangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tl = s.voiceLang == 'tl';
    return Tooltip(
      message: tr(context, 'Language you are speaking', 'Wikang ginagamit mo'),
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            s.voiceLang = tl ? 'en' : 'tl';
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.translate_rounded, size: 15, color: cs.primary),
              const SizedBox(width: 5),
              Text(tl ? 'Filipino' : 'English', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Records up to 30 s of speech (for dictating statements) and returns the
/// transcript, or null if cancelled.
Future<String?> showVoiceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  // Dictation has natural pauses, so wait longer before stopping.
  late final _voice = VoiceCapture(silenceToStop: const Duration(milliseconds: 2800), onAutoStop: _done);
  bool _needModel = false;

  @override
  void initState() {
    super.initState();
    _needModel = !AiService.instance.voiceReady;
    if (!_needModel) WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() => _voice.start(permissionMessage: tr(context, 'Microphone permission is needed.', 'Kailangan ng pahintulot sa mikropono.'));

  Future<void> _done() async {
    if (_voice.phase != VoicePhase.recording) return;
    final text = await _voice.finish(AppScope.read(context).voiceLang);
    if (!mounted) return;
    if (_voice.phase != VoicePhase.error) Navigator.pop(context, text);
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ListenableBuilder(
          listenable: Listenable.merge([AiService.instance, _voice]),
          builder: (context, _) {
            final ai = AiService.instance;
            if (_needModel) {
              if (ai.voiceReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _needModel) {
                    setState(() => _needModel = false);
                    _begin();
                  }
                });
              }
              final v = recommendedVoice(AppScope.of(context).device.tier);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_none_rounded, size: 48, color: cs.primary),
                const SizedBox(height: 12),
                Text(tr(context, 'Setting up voice input', 'Inihahanda ang voice input'), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  ai.voiceBundled
                      ? tr(context, 'The voice model is built in. It is being prepared on this phone.', 'Kasama na ang voice model. Inihahanda ito sa phone na ito.')
                      : tr(context, '${v.name}, ${v.sizeMb} MB, one-time download. After that, voice works offline.',
                          '${v.name}, ${v.sizeMb} MB, isang beses na download. Pagkatapos, offline na ang boses.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                if (ai.voiceDownloading)
                  LinearProgressIndicator(value: ai.voiceProgress / 100, borderRadius: BorderRadius.circular(99), minHeight: 6)
                else
                  FilledButton.icon(
                    onPressed: () => ai.installVoice(v),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(tr(context, 'Set up voice', 'I-set up ang boses')),
                  ),
              ]);
            }
            final phase = _voice.phase;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                switch (phase) {
                  VoicePhase.recording => tr(context, 'Listening…', 'Nakikinig…'),
                  VoicePhase.transcribing => tr(context, 'Writing it down…', 'Isinusulat…'),
                  VoicePhase.error => tr(context, 'Something went wrong', 'May nangyaring mali'),
                  _ => tr(context, 'Starting…', 'Sinisimulan…'),
                },
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                phase == VoicePhase.error
                    ? (_voice.error ?? '')
                    : tr(context, 'Stays on this phone · ${VoiceCapture.maxSeconds + 1 - _voice.seconds}s left',
                        'Nasa phone lang · ${VoiceCapture.maxSeconds + 1 - _voice.seconds}s na lang'),
                style: TextStyle(color: phase == VoicePhase.error ? t.danger : cs.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              VoiceWave(levels: _voice.levels, active: phase == VoicePhase.recording, height: 64, barWidth: 5),
              const SizedBox(height: 14),
              const VoiceLangToggle(),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Cancel', 'Kanselahin'))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: phase == VoicePhase.recording ? _done : (phase == VoicePhase.error ? _begin : null),
                    icon: phase == VoicePhase.transcribing
                        ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary))
                        : Icon(phase == VoicePhase.error ? Icons.refresh_rounded : Icons.check_rounded),
                    label: Text(phase == VoicePhase.error ? tr(context, 'Try again', 'Ulitin') : tr(context, 'Done', 'Tapos na')),
                  ),
                ),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

/// The samples of a 16 kHz mono 16-bit WAV file, without its header.
Uint8List pcmFromWav(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  var offset = 12;
  while (offset + 8 <= wav.length) {
    final id = String.fromCharCodes(wav, offset, offset + 4);
    final size = view.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (id == 'data') {
      // Some recorders leave the size at 0 or 0xFFFFFFFF while streaming; take the rest.
      final end = size == 0 || start + size > wav.length ? wav.length : start + size;
      return Uint8List.sublistView(wav, start, end);
    }
    offset = start + size + (size & 1);
  }
  throw const FormatException('WAV file has no data chunk');
}
