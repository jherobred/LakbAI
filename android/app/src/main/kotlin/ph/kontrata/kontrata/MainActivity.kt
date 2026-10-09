package ph.kontrata.kontrata

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Reports RAM so the app can pick a model size the phone can actually run.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kontrata/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val mem = ActivityManager.MemoryInfo()
                    am.getMemoryInfo(mem)
                    result.success(
                        mapOf(
                            "totalMb" to (mem.totalMem / (1024 * 1024)).toInt(),
                            "availMb" to (mem.availMem / (1024 * 1024)).toInt(),
                            "isLowRam" to am.isLowRamDevice,
                            "platform" to "android",
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
