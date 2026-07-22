package br.com.rhm.rhm_coletor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val scannerChannel = "br.com.rhm.rhm_coletor/scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, scannerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasNativeScanner" -> result.success(isIndustrialScanner())
                    "triggerLaser" -> result.success(triggerLaser())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIndustrialScanner(): Boolean {
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
        val brand = Build.BRAND.orEmpty().lowercase()
        val fingerprint = Build.FINGERPRINT.orEmpty().lowercase()
        val identifiers = "$manufacturer $brand $fingerprint"
        return listOf("urovo", "honeywell", "zebra", "datalogic", "complex", "chainway")
            .any { identifiers.contains(it) }
    }

    private fun triggerLaser(): Boolean {
        if (!isIndustrialScanner()) return false
        return try {
            // Urovo/Complex configurados para o Intent Scanner Trigger aceitam
            // esta ação. A tecla física e o keyboard wedge continuam funcionando.
            sendBroadcast(Intent("android.intent.action.SCANNER_TRIGGER").apply {
                putExtra("SCANKEY", true)
            })
            true
        } catch (_: Exception) {
            false
        }
    }
}
