import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  const VoiceOption({required this.id, required this.name, required this.modelUrl, required this.tokenizerUrl, required this.sizeMb});
  final String id;
  final String name;
  final String modelUrl;
  final String tokenizerUrl;
  final int sizeMb;
}

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
  ),
];

ModelOption recommendedModel(DeviceTier tier) => kModels.firstWhere((m) => m.tier == tier);
VoiceOption recommendedVoice(DeviceTier tier) => tier == DeviceTier.low ? kVoices.first : kVoices.last;
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

  Future<void> init(AppState app) async {
    _app = app;
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
      active = modelById(id) ?? (id == 'imported' ? null : null);
      // Load in the background so the first screen is never blocked.
      unawaited(_activateInstalled());
    }
    notifyListeners();
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
        await FlutterEdgeAi.installModel(modelType: m.type, fileType: ModelFileType.litertlm).fromNetwork(m.url).install();
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
    try {
      await FlutterEdgeAi.installModel(modelType: m.type, fileType: ModelFileType.litertlm)
          .fromNetwork(m.url)
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
  }

  /// Streams a reply token by token. Each question gets a fresh chat so a
  /// small model never runs out of context.
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
      await for (final r in _chat!.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
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
      await FlutterEdgeAi.installStt()
          .modelFromNetwork(v.modelUrl)
          .tokenizerFromNetwork(v.tokenizerUrl)
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
    _stt ??= await FlutterEdgeAi.getActiveStt(language: language);
    final text = await _stt!.transcribe(pcm, language: language);
    return text.trim();
  }
}

/// Small models sometimes leak template tokens or think-tags; strip them.
String cleanModelText(String s) {
  var t = s.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  t = t.replaceAll(RegExp(r'<\|[^|]*\|>'), '');
  t = t.replaceAll(RegExp(r'</?(start_of_turn|end_of_turn|eos|bos)>'), '');
  return t.trim();
}
