package pe.edu.cropscan

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.FileNotFoundException

class MainActivity : FlutterActivity() {
    private var inferenceChannel: MethodChannel? = null
    private var experimentalChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        if (applicationContext.packageName == "pe.edu.cropscan.experimental") {
            experimentalChannel = experimentalInferenceChannel(messenger, applicationContext.assets)
            return
        }
        val classifier = CropClassifier(applicationContext.assets)
        inferenceChannel = MethodChannel(
            messenger,
            "pe.edu.cropscan/inference",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method != "analyze" && call.method != "analyzePrototype") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val photo = call.arguments as? ByteArray
                if (photo == null || photo.isEmpty()) {
                    result.error("invalid_photo", null, null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(classifier.analyze(photo, prototype = call.method == "analyzePrototype"))
                } catch (_: FileNotFoundException) {
                    result.error("model_missing", null, null)
                } catch (error: Exception) {
                    Log.e("CropScan", "Local inference failed", error)
                    result.error("inference_failed", null, null)
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        experimentalChannel?.setMethodCallHandler(null)
        experimentalChannel = null
        inferenceChannel?.setMethodCallHandler(null)
        inferenceChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
