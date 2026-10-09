import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceTier { low, mid, high }

enum MotionMode { auto, lite, full }

class DeviceProfile {
  const DeviceProfile({
    required this.totalMb,
    required this.isLowRam,
    required this.platform,
    required this.model,
    required this.sdkInt,
  });

  final int totalMb;
  final bool isLowRam;
  final String platform;
  final String model;
  final int sdkInt;

  /// Phones report a little less than their marketed RAM (a "4 GB" phone shows ~3.7 GB).
  DeviceTier get tier {
    if (isLowRam || totalMb < 4600) return DeviceTier.low;
    if (totalMb < 7400) return DeviceTier.mid;
    return DeviceTier.high;
  }

  String get ramLabel => '${(totalMb / 1024).toStringAsFixed(totalMb < 10240 ? 1 : 0)} GB';

  static const fallback = DeviceProfile(totalMb: 6000, isLowRam: false, platform: 'unknown', model: 'Unknown', sdkInt: 0);

  static Future<DeviceProfile> read() async {
    try {
      final m = await const MethodChannel('kontrata/device').invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (m == null) return fallback;
      return DeviceProfile(
        totalMb: (m['totalMb'] as num?)?.toInt() ?? 6000,
        isLowRam: m['isLowRam'] as bool? ?? false,
        platform: m['platform'] as String? ?? 'unknown',
        model: m['model'] as String? ?? 'Unknown',
        sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return fallback;
    }
  }
}

/// App-wide settings and preferences. Everything here stays on the phone.
class AppState extends ChangeNotifier {
  AppState._(this._prefs, this.device);

  final SharedPreferences _prefs;
  final DeviceProfile device;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final device = await DeviceProfile.read();
    return AppState._(prefs, device);
  }

  ThemeMode get themeMode => ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
  set themeMode(ThemeMode v) {
    _prefs.setInt('themeMode', v.index);
    notifyListeners();
  }

  /// 'en' or 'fil'
  String get lang => _prefs.getString('lang') ?? 'fil';
  set lang(String v) {
    _prefs.setString('lang', v);
    notifyListeners();
  }

  bool get isFil => lang == 'fil';

  /// Whisper language for the microphone: 'tl' or 'en'. Follows the app language until changed.
  String get voiceLang => _prefs.getString('voiceLang') ?? (isFil ? 'tl' : 'en');
  set voiceLang(String v) {
    _prefs.setString('voiceLang', v);
    notifyListeners();
  }

  MotionMode get motionMode => MotionMode.values[_prefs.getInt('motionMode') ?? MotionMode.auto.index];
  set motionMode(MotionMode v) {
    _prefs.setInt('motionMode', v.index);
    notifyListeners();
  }

  /// Lite mode trims animation work on low-RAM phones unless the user overrides it.
  bool get liteMode {
    switch (motionMode) {
      case MotionMode.lite:
        return true;
      case MotionMode.full:
        return false;
      case MotionMode.auto:
        return device.tier == DeviceTier.low;
    }
  }

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  set onboarded(bool v) {
    _prefs.setBool('onboarded', v);
    notifyListeners();
  }

  String? get installedModelId => _prefs.getString('installedModelId');
  set installedModelId(String? v) {
    if (v == null) {
      _prefs.remove('installedModelId');
    } else {
      _prefs.setString('installedModelId', v);
    }
    notifyListeners();
  }

  String? get importedModelPath => _prefs.getString('importedModelPath');
  set importedModelPath(String? v) {
    if (v == null) {
      _prefs.remove('importedModelPath');
    } else {
      _prefs.setString('importedModelPath', v);
    }
  }

  String? get installedVoiceId => _prefs.getString('installedVoiceId');
  set installedVoiceId(String? v) {
    if (v == null) {
      _prefs.remove('installedVoiceId');
    } else {
      _prefs.setString('installedVoiceId', v);
    }
    notifyListeners();
  }

  /// Destination country code the user picked (hk, sg, ksa, uae, kw, qa, other).
  String? get country => _prefs.getString('country');
  set country(String? v) {
    if (v == null) {
      _prefs.remove('country');
    } else {
      _prefs.setString('country', v);
    }
    notifyListeners();
  }

  // ---- App lock (PIN). Stored as a salted SHA-256 hash, never as the PIN itself.
  bool get hasPin => _prefs.getString('pinHash') != null;

  void setPin(String pin) {
    final salt = base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    _prefs.setString('pinSalt', salt);
    _prefs.setString('pinHash', _hash(pin, salt));
    _prefs.setInt('pinLength', pin.length);
    notifyListeners();
  }

  /// Digits in the saved PIN. Null for PINs saved before the length was
  /// stored; the first successful unlock records it.
  int? get pinLength => _prefs.getInt('pinLength');

  void clearPin() {
    _prefs.remove('pinSalt');
    _prefs.remove('pinHash');
    _prefs.remove('pinLength');
    notifyListeners();
  }

  bool checkPin(String pin) {
    final salt = _prefs.getString('pinSalt');
    final hash = _prefs.getString('pinHash');
    if (salt == null || hash == null) return true;
    final ok = _hash(pin, salt) == hash;
    if (ok && pinLength == null) _prefs.setInt('pinLength', pin.length);
    return ok;
  }

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> wipe() async {
    await _prefs.clear();
    notifyListeners();
  }
}

/// Gives every widget below it access to [AppState] and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Picks the English or Filipino string for the current language.
String tr(BuildContext context, String en, String fil) => AppScope.of(context).isFil ? fil : en;

/// Animation timing that respects lite mode and the OS "remove animations" setting.
class Motion {
  static bool reduced(BuildContext context) =>
      AppScope.of(context).liteMode || MediaQuery.of(context).disableAnimations;

  static Duration d(BuildContext context, int ms) {
    if (MediaQuery.of(context).disableAnimations) return Duration.zero;
    if (AppScope.of(context).liteMode) return Duration(milliseconds: (ms * 0.55).round());
    return Duration(milliseconds: ms);
  }
}
