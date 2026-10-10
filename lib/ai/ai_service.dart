import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';

import '../core/app_state.dart';

/// A language model the phone can download once and then run offline.
class ModelOption {
  const ModelOption({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeMb,
    required this.type,
    required this.tier,
    required this.blurbEn,
    required this.blurbFil,
    this.vision = false,
  });

  final String id;
  final String name;
  final String url;
  final int sizeMb;
  final ModelType type;
  final DeviceTier tier;
  final String blurbEn;
  final String blurbFil;
  final bool vision;

  String get sizeLabel => sizeMb >= 1000 ? '${(sizeMb / 1000).toStringAsFixed(1)} GB' : '$sizeMb MB';
}

class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.name,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.sizeMb,
    this.modelAsset,
    this.tokenizerAsset,
  });
  final String id;
  final String name;
  final String modelUrl;
  final String tokenizerUrl;
  final int sizeMb;

  /// Set when the installer ships this voice model (see tool/fetch_models.sh).
  final String? modelAsset;
  final String? tokenizerAsset;
}

/// Model files packed into the installer by tool/fetch_models.sh. Builds made
/// without them fall back to the one-time download.
const kBundledModelAsset = 'assets/models/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';
const kBundledModelId = 'qwen3-0.6b-lite';

/// All models are Apache-2.0 and ungated on Hugging Face, so no token is needed.
const kModels = <ModelOption>[
  ModelOption(
    id: 'qwen3-0.6b-lite',
    name: 'Qwen3 0.6B Lite',
    url: 'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    sizeMb: 345,
    type: ModelType.qwen3,
    tier: DeviceTier.low,
    blurbEn: 'Smallest download. Runs on 3–4 GB phones.',
    blurbFil: 'Pinakamaliit na download. Kaya ng 3–4 GB na phone.',
  ),
  ModelOption(
    id: 'qwen3-0.6b',
    name: 'Qwen3 0.6B',
    url: 'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
    sizeMb: 614,
    type: ModelType.qwen3,
    tier: DeviceTier.mid,
    blurbEn: 'Better answers. Good for 4–6 GB phones.',
    blurbFil: 'Mas maayos na sagot. Para sa 4–6 GB na phone.',
  ),
  ModelOption(
    id: 'gemma4-e2b',
    name: 'Gemma 4 E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    sizeMb: 2588,
    type: ModelType.gemma4,
    tier: DeviceTier.high,
    vision: true,
    blurbEn: 'Best answers and Filipino. For 8 GB+ phones.',
    blurbFil: 'Pinakamahusay na sagot at Filipino. Para sa 8 GB pataas.',
  ),
];

const kVoices = <VoiceOption>[
  VoiceOption(
    id: 'whisper-tiny',
    name: 'Whisper tiny',
    modelUrl: 'https://huggingface.co/litert-community/whisper-tiny/resolve/main/whisper_tiny_30s_i8.tflite',
    tokenizerUrl: 'https://huggingface.co/openai/whisper-tiny/resolve/main/tokenizer.json',
    sizeMb: 43,
  ),
  VoiceOption(
    id: 'whisper-base',
    name: 'Whisper base',
    modelUrl: 'https://huggingface.co/litert-community/whisper-base/resolve/main/whisper_base_30s_i8.tflite',
    tokenizerUrl: 'https://huggingface.co/openai/whisper-base/resolve/main/tokenizer.json',
    sizeMb: 80,
    modelAsset: 'assets/models/whisper_base_30s_i8.tflite',
    tokenizerAsset: 'assets/models/whisper_base_tokenizer.json',
  ),
];

ModelOption recommendedModel(DeviceTier tier) => kModels.firstWhere((m) => m.tier == tier);

/// The built-in voice when the installer has it, otherwise the best download for the phone.
VoiceOption recommendedVoice(DeviceTier tier) =>
    AiService.instance.voiceBundled ? kVoices.last : (tier == DeviceTier.low ? kVoices.first : kVoices.last);
ModelOption? modelById(String? id) => kModels.where((m) => m.id == id).firstOrNull;

enum AiStatus { notInstalled, downloading, loading, ready, error }

/// Runs the on-device language model and speech recognizer.
/// Nothing in here sends user text or audio off the phone.
class AiService extends ChangeNotifier {
  AiService._();
  static final AiService instance = AiService._();

  late AppState _app;
  AiStatus status = AiStatus.notInstalled;
  int progress = 0;
  String? error;
  ModelOption? active;
  CancelToken? _cancel;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _busy = false;
  bool get busy => _busy;

  bool voiceReady = false;
  bool voiceDownloading = false;
  int voiceProgress = 0;
  SpeechRecognizer? _stt;

  bool get ready => status == AiStatus.ready;

  /// Whether the active model writes usable Filipino. Qwen3 0.6B does not.
  bool get writesFilipino => active?.type == ModelType.gemma4;

  /// True when the installer carries the model files, so nothing has to be downloaded.
  bool modelBundled = false;
  bool voiceBundled = false;

  Future<void> _detectBundled() async {
    try {
      final assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
      modelBundled = assets.contains(kBundledModelAsset);
      final v = kVoices.last;
      voiceBundled = assets.contains(v.modelAsset) && assets.contains(v.tokenizerAsset);
    } catch (_) {}
  }

  Future<void> init(AppState app) async {
    _app = app;
    await _detectBundled();
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
        sttBackends: [LiteRtSttBackend()],
      );
    } catch (e) {
      error = '$e';
    }
    voiceReady = app.installedVoiceId != null;
    final id = app.installedModelId;
    if (id != null) {
      active = modelById(id);
      // Load in the background so the first screen is never blocked.
      unawaited(_activateInstalled().then((_) => _setUpBundledVoice()));
    } else if (modelBundled) {
      // First launch of an installer that carries the model: unpack it, no download.
      unawaited(install(modelById(kBundledModelId)!).then((_) => _setUpBundledVoice()));
    } else {
      unawaited(_setUpBundledVoice());
    }
    notifyListeners();
  }

  Future<void> _setUpBundledVoice() async {
    if (!voiceReady && voiceBundled) await installVoice(kVoices.last);
    // Open the recognizer early so the first voice message is not slowed by loading it.
    if (voiceReady) {
      try {
        _stt ??= await FlutterEdgeAi.getActiveStt();
      } catch (_) {}
    }
  }

  /// The install builder for [m]: the copy inside the installer when there is one.
  InferenceInstallationBuilder _source(ModelOption m) {
    final b = FlutterEdgeAi.installModel(modelType: m.type, fileType: ModelFileType.litertlm);
    return m.id == kBundledModelId && modelBundled ? b.fromAsset(kBundledModelAsset) : b.fromNetwork(m.url);
  }

  Future<void> _activateInstalled() async {
    final id = _app.installedModelId;
    if (id == null) return;
    status = AiStatus.loading;
    notifyListeners();
    // Offline first: the active model is remembered across launches, so try
    // loading it straight from disk before touching the installer at all.
    try {
      await _load();
      return;
    } catch (_) {}
    try {
      // install() skips the download when the file is already on disk and
      // marks the model as the one getActiveModel loads.
      if (id == 'imported' && _app.importedModelPath != null) {
        await FlutterEdgeAi.installModel(modelType: ModelType.general, fileType: ModelFileType.litertlm)
            .fromFile(_app.importedModelPath!)
            .install();
      } else {
        final m = modelById(id);
        if (m == null) {
          status = AiStatus.notInstalled;
          notifyListeners();
          return;
        }
        await _source(m).install();
      }
      await _load();
    } catch (e) {
      status = AiStatus.error;
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> install(ModelOption m) async {
    if (status == AiStatus.downloading) return;
    _cancel = CancelToken();
    status = AiStatus.downloading;
    progress = 0;
    error = null;
    active = m;
    notifyListeners();
    // Unpacking the built-in model takes seconds and needs no network, so it shows as loading.
    if (m.id == kBundledModelId && modelBundled) status = AiStatus.loading;
    notifyListeners();
    try {
      await _source(m)
          .withCancelToken(_cancel!)
          .withProgress((p) {
            progress = p;
            notifyListeners();
          })
          .install();
      _app.installedModelId = m.id;
      await _load();
    } catch (e) {
      status = AiStatus.error;
      error = '$e';
      notifyListeners();
    }
  }

  /// Installs a .litertlm file already on the phone (for example copied over USB).
  Future<void> importFile(String path) async {
    status = AiStatus.loading;
    error = null;
    notifyListeners();
    try {
      await FlutterEdgeAi.installModel(modelType: ModelType.general, fileType: ModelFileType.litertlm).fromFile(path).install();
      _app.importedModelPath = path;
      _app.installedModelId = 'imported';
      active = null;
      await _load();
    } catch (e) {
      status = AiStatus.error;
      error = '$e';
      notifyListeners();
    }
  }

  void cancelDownload() {
    _cancel?.cancel();
    status = AiStatus.notInstalled;
    notifyListeners();
  }

  Future<void> _load() async {
    status = AiStatus.loading;
    notifyListeners();
    final low = _app.device.tier == DeviceTier.low;
    _model = await FlutterEdgeAi.getActiveModel(
      maxTokens: low ? 1536 : 2560,
      // Low-RAM phones share GPU memory with the system, so stay on CPU there.
      preferredBackend: low ? PreferredBackend.cpu : null,
    );
    status = AiStatus.ready;
    notifyListeners();
    unawaited(_warmUp());
  }

  /// Runs one tiny reply right after loading, so the one-time engine start-up
  /// cost is paid before the worker asks anything.
  Future<void> _warmUp() async {
    try {
      await for (final _ in ask(system: 'Reply with OK.', prompt: 'Hi', maxOutputTokens: 2)) {}
    } catch (_) {}
  }

  /// Streams a reply token by token. Each question gets a fresh chat so a
  /// small model never runs out of context. Generation stops early once the
  /// model starts repeating itself, so a loop does not burn the token budget.
  Stream<String> ask({required String system, required String prompt, int maxOutputTokens = 360}) async* {
    if (_model == null) throw StateError('model-not-ready');
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    _busy = true;
    notifyListeners();
    try {
      _chat = await _model!.createChat(
        systemInstruction: system,
        temperature: 0.3,
        topK: 24,
        maxOutputTokens: maxOutputTokens,
        enableThinking: false,
      );
      await _chat!.addQueryChunk(Message(text: prompt, isUser: true));
      final raw = StringBuffer();
      var halted = false;
      await for (final r in _chat!.generateChatResponseAsync()) {
        if (r is! TextResponse || halted) continue;
        raw.write(r.token);
        yield r.token;
        if (isLooping(raw.toString())) {
          halted = true;
          // Same path as the user's stop: the stream ends on its own after this.
          unawaited(_chat!.stopGeneration().catchError((_) {}));
        }
      }
    } finally {
      try {
        await _chat?.close();
      } catch (_) {}
      _chat = null;
      _busy = false;
      notifyListeners();
    }
  }

  /// Collects a whole reply (used for report wording and explanations).
  Future<String> complete({required String system, required String prompt, int maxOutputTokens = 420}) async {
    final b = StringBuffer();
    await for (final t in ask(system: system, prompt: prompt, maxOutputTokens: maxOutputTokens)) {
      b.write(t);
    }
    return cleanModelText(b.toString());
  }

  Future<void> stop() async {
    try {
      await _chat?.stopGeneration();
    } catch (_) {}
  }

  Future<void> deleteModel() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    final id = _app.installedModelId;
    if (id != null) {
      try {
        final ids = await FlutterEdgeAi.listInstalledModels();
        for (final m in ids) {
          await FlutterEdgeAi.uninstallModel(m);
        }
      } catch (_) {}
    }
    _app.installedModelId = null;
    _app.importedModelPath = null;
    active = null;
    status = AiStatus.notInstalled;
    notifyListeners();
  }

  // ---------------- Voice (Whisper, on-device) ----------------

  Future<void> installVoice(VoiceOption v) async {
    if (voiceDownloading) return;
    voiceDownloading = true;
    voiceProgress = 0;
    notifyListeners();
    try {
      final b = FlutterEdgeAi.installStt();
      if (voiceBundled && v.modelAsset != null) {
        b.modelFromAsset(v.modelAsset!).tokenizerFromAsset(v.tokenizerAsset!);
      } else {
        b.modelFromNetwork(v.modelUrl).tokenizerFromNetwork(v.tokenizerUrl);
      }
      await b
          .ofType(SttModelType.whisper)
          .withModelProgress((p) {
            voiceProgress = p;
            notifyListeners();
          })
          .install();
      _app.installedVoiceId = v.id;
      voiceReady = true;
    } catch (e) {
      error = '$e';
    } finally {
      voiceDownloading = false;
      notifyListeners();
    }
  }

  /// [pcm] is 16 kHz mono 16-bit PCM. [language] is a Whisper code: 'tl' or 'en'.
  Future<String> transcribe(Uint8List pcm, String language) async {
    try {
      _stt ??= await FlutterEdgeAi.getActiveStt();
    } on StateError {
      // The recognizer was forgotten (for example after an update): set it up again.
      voiceReady = false;
      await _setUpBundledVoice();
      _stt ??= await FlutterEdgeAi.getActiveStt();
    }
    return cleanTranscript(await _stt!.transcribe(pcm, language: language));
  }
}

final _sourceLine = RegExp(r'^\s*(?:[-*•]\s*)?\**\s*(?:source|sources|pinagmulan|batayan)\s*\**\s*:\s*\**\s*"?(.*?)[\s*"]*$', caseSensitive: false);
final _trailingSource = RegExp(r'^(.*[.!?])\s+\**source\**\s*:\s*(.+)$', caseSensitive: false);
final _doubleBullet = RegExp(r'^(\s*)[-*•]\s+["“]?[-*•]\s+');
final _echo = RegExp(
    r'^(\s*(?:[-*•]|\d+\.)\s+)?\**\s*(?:one short sentence(?: that answers(?: the question)?)?|bold(?: numbers)?|last line|bullet points?(?: (?:that )?start(?:s|ing)? with "- ")?)\s*\**\s*(?::\s*\**\s*|$)',
    caseSensitive: false);

/// Small models leak template tokens and think-tags, copy words from the
/// format instructions ("**Bold**:"), repeat lines, and write the
/// "Source:" line more than once. Strip all of that and keep one Source
/// line at the end.
String cleanModelText(String s) {
  var t = s.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  t = t.replaceAll(RegExp(r'<\|[^|]*\|>'), '');
  t = t.replaceAll(RegExp(r'</?(start_of_turn|end_of_turn|eos|bos)>'), '');
  final kept = <String>[];
  String? source;
  for (var line in t.split('\n')) {
    final blank = line.trim().isEmpty;
    line = line.replaceFirstMapped(_doubleBullet, (m) => '${m[1]}- ');
    line = line.replaceFirstMapped(_echo, (m) => m[1] ?? '');
    // Nothing but bullet marks left (an echo, or "- " before an indented line).
    if (!blank && line.replaceAll(RegExp(r'[-*•\s]'), '').isEmpty) continue;
    // A bullet the model wrapped in quotes often loses its opening quote.
    if ('"'.allMatches(line).length == 1) line = line.replaceFirst('"', '');
    final inline = _trailingSource.firstMatch(line);
    if (inline != null) {
      source ??= inline[2]!.trim();
      line = inline[1]!;
    }
    final src = _sourceLine.firstMatch(line);
    if (src != null) {
      final law = src[1]!.trim();
      if (law.isNotEmpty && !law.contains('<')) source ??= law;
      continue;
    }
    if (line.trim().isNotEmpty && kept.any((k) => _nearDuplicate(k, line))) continue;
    kept.add(line);
  }
  var out = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (source != null) out = '$out\n\nSource: $source';
  return out.trim();
}

List<String> _words(String s) => s.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty).toList();

/// Two lines of five or more words that share at least 90% of their words.
/// Lines that differ by one number stay apart, so distinct facts survive.
bool _nearDuplicate(String a, String b) {
  final x = _words(a).toSet();
  final y = _words(b).toSet();
  if (x.length < 5 || y.length < 5) return false;
  return x.intersection(y).length / x.union(y).length >= 0.9;
}

/// True once a reply has started to loop: a finished line that nearly
/// repeats an earlier one, a second Source line, or the same four words
/// three times.
bool isLooping(String text) {
  final words = _words(text);
  if (words.length >= 12) {
    final last = words.sublist(words.length - 4).join(' ');
    var seen = 0;
    for (var i = 0; i + 4 <= words.length; i++) {
      if (words.sublist(i, i + 4).join(' ') == last && ++seen >= 3) return true;
    }
  }
  final lines = text.split('\n');
  final done = lines.sublist(0, lines.length - 1).where((l) => l.trim().isNotEmpty).toList();
  if (done.where(_sourceLine.hasMatch).length >= 2) return true;
  if (done.length < 2) return false;
  final latest = done.last;
  return done.sublist(0, done.length - 1).any((l) => _nearDuplicate(l, latest));
}

/// Whisper writes tags like [BLANK_AUDIO] or (music) for silence and noise,
/// and sometimes stock phrases when nothing was said. Drop those.
String cleanTranscript(String s) {
  var t = s.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)|<\|[^|]*\|>'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  const noise = {'thank you.', 'thanks for watching!', 'thank you for watching.', 'you', 'salamat po.', '.'};
  return noise.contains(t.toLowerCase()) ? '' : t;
}
