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

/// Records up to 30 s of speech and turns it into text with Whisper, on the phone.
/// Returns the transcript, or null if cancelled.
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

enum _Phase { needModel, idle, recording, transcribing, error }

class _VoiceSheetState extends State<_VoiceSheet> {
  final _rec = AudioRecorder();
  _Phase _phase = _Phase.idle;
  final List<double> _levels = List.filled(28, 0.05);
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  int _seconds = 0;
  String? _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!AiService.instance.voiceReady) {
      _phase = _Phase.needModel;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      setState(() {
        _phase = _Phase.error;
        _error = tr(context, 'Microphone permission is needed.', 'Kailangan ng pahintulot sa mikropono.');
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: _path!);
    HapticFeedback.mediumImpact();
    _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
      // dBFS (-60..0) to 0..1
      final v = ((a.current + 55) / 55).clamp(0.04, 1.0);
      setState(() {
        _levels.removeAt(0);
        _levels.add(v);
      });
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _seconds++);
      if (_seconds >= 29) _stop();
    });
    setState(() => _phase = _Phase.recording);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    final path = await _rec.stop() ?? _path;
    if (!mounted) return;
    setState(() => _phase = _Phase.transcribing);
    try {
      final wav = await File(path!).readAsBytes();
      final pcm = pcmFromWav(wav);
      final text = await AiService.instance.transcribe(pcm, AppScope.read(context).isFil ? 'tl' : 'en');
      if (mounted) Navigator.pop(context, text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = '$e';
        });
      }
    } finally {
      try {
        await File(path!).delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ListenableBuilder(
          listenable: AiService.instance,
          builder: (context, _) {
            final ai = AiService.instance;
            if (_phase == _Phase.needModel) {
              if (ai.voiceReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _phase == _Phase.needModel) {
                    setState(() => _phase = _Phase.idle);
                    _start();
                  }
                });
              }
              final v = recommendedVoice(AppScope.of(context).device.tier);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_off_rounded, size: 48, color: cs.primary),
                const SizedBox(height: 12),
                Text(tr(context, 'Voice needs a one-time download', 'Kailangan ng isang beses na download para sa boses'),
                    style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  tr(context, '${v.name}, ${v.sizeMb} MB. After that, your voice is turned into text on this phone, offline.',
                      '${v.name}, ${v.sizeMb} MB. Pagkatapos, gagawing text ang boses mo sa phone na ito, offline.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                if (ai.voiceDownloading)
                  LinearProgressIndicator(value: ai.voiceProgress / 100, borderRadius: BorderRadius.circular(99), minHeight: 8)
                else
                  FilledButton.icon(
                    onPressed: () => ai.installVoice(v),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(tr(context, 'Download voice model', 'I-download ang voice model')),
                  ),
              ]);
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                switch (_phase) {
                  _Phase.recording => tr(context, 'Listening… speak naturally', 'Nakikinig… magsalita lang'),
                  _Phase.transcribing => tr(context, 'Turning your voice into text…', 'Ginagawang text ang boses mo…'),
                  _Phase.error => tr(context, 'Something went wrong', 'May nangyaring mali'),
                  _ => tr(context, 'Starting…', 'Sinisimulan…'),
                },
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _phase == _Phase.error ? (_error ?? '') : tr(context, 'Stays on this phone · ${30 - _seconds}s left', 'Nasa phone lang · ${30 - _seconds}s na lang'),
                style: TextStyle(color: _phase == _Phase.error ? t.danger : cs.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 64,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  for (var i = 0; i < _levels.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 5,
                      height: _phase == _Phase.recording ? 6 + 58 * _levels[i] * (0.6 + 0.4 * math.sin(i / 2).abs()) : 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [cs.primary, KColors.cyan], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'Cancel', 'Kanselahin'))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _phase == _Phase.recording ? _stop : null,
                    icon: _phase == _Phase.transcribing
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Icon(Icons.stop_rounded),
                    label: Text(tr(context, 'Done', 'Tapos na')),
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
      final end = start + size > wav.length ? wav.length : start + size;
      return Uint8List.sublistView(wav, start, end);
    }
    offset = start + size + (size & 1);
  }
  throw const FormatException('WAV file has no data chunk');
}
