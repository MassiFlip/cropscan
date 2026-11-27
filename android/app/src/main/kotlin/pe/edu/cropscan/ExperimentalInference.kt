package pe.edu.cropscan

import android.content.res.AssetManager
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.FileNotFoundException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.ceil

internal fun experimentalInferenceChannel(
    messenger: BinaryMessenger,
    assets: AssetManager,
): MethodChannel = MethodChannel(
    messenger,
    "pe.edu.cropscan/experimental",
    StandardMethodCodec.INSTANCE,
    messenger.makeBackgroundTaskQueue(),
).apply {
    setMethodCallHandler { call, result ->
        if (call.method != "analyze") {
            result.notImplemented()
            return@setMethodCallHandler
        }
        val photo = call.arguments as? ByteArray
        if (photo == null || photo.isEmpty()) {
            result.error("invalid_photo", null, null)
            return@setMethodCallHandler
        }
        try {
            result.success(runExperimentalInference(assets, photo))
        } catch (_: FileNotFoundException) {
            result.error("model_missing", null, null)
        } catch (error: Exception) {
            Log.e("CropScanExperimental", "Local inference failed", error)
            result.error("inference_failed", null, null)
        } catch (error: LinkageError) {
            Log.e("CropScanExperimental", "LiteRT native library unavailable", error)
            result.error("inference_failed", null, null)
        }
    }
}

private fun runExperimentalInference(assets: AssetManager, photo: ByteArray): Map<String, Any> {
    val size = 160
    val repetitions = 10
    val loadStarted = SystemClock.elapsedRealtimeNanos()
    val model = assets.open("cropscan_experimental.tflite").use { it.readBytes() }
    val modelBuffer = ByteBuffer.allocateDirect(model.size).order(ByteOrder.nativeOrder())
    modelBuffer.put(model).rewind()
    return Interpreter(modelBuffer, Interpreter.Options().setNumThreads(2)).use { interpreter ->
        interpreter.allocateTensors()
        require(interpreter.inputTensorCount == 1 && interpreter.outputTensorCount == 1)
        val inputTensor = interpreter.getInputTensor(0)
        val outputTensor = interpreter.getOutputTensor(0)
        require(inputTensor.dataType() == DataType.FLOAT32 &&
            inputTensor.shape().contentEquals(intArrayOf(1, size, size, 3)))
        require(outputTensor.dataType() == DataType.FLOAT32 &&
            outputTensor.shape().contentEquals(intArrayOf(1, 2)))
        val loadMs = millisecondsSince(loadStarted)
        val prepareStarted = SystemClock.elapsedRealtimeNanos()
        val input = cropImageInput(photo, size, size, inputTensor.numBytes())
        val prepareMs = millisecondsSince(prepareStarted)
        val output = Array(1) { FloatArray(2) }
        repeat(3) {
            input.rewind()
            interpreter.run(input, output)
        }
        var maxDifference = 0.0
        val reference = output.single().copyOf()
        val times = List(repetitions) {
            input.rewind()
            val started = SystemClock.elapsedRealtimeNanos()
            interpreter.run(input, output)
            val elapsed = millisecondsSince(started)
            val scores = output.single()
            require(scores.all { it.isFinite() && it in 0f..1f } &&
                abs(scores.sum() - 1f) < 0.001f)
            for (index in scores.indices) {
                maxDifference = maxOf(maxDifference, abs(scores[index] - reference[index]).toDouble())
            }
            elapsed
        }.sorted()
        mapOf(
            "scores" to reference.map(Float::toDouble),
            "loadMs" to loadMs,
            "prepareMs" to prepareMs,
            "medianMs" to (times[repetitions / 2 - 1] + times[repetitions / 2]) / 2,
            "p95Ms" to times[ceil(repetitions * 0.95).toInt() - 1],
            "repetitions" to repetitions,
            "maxScoreDelta" to maxDifference,
        )
    }
}

private fun millisecondsSince(started: Long) =
    (SystemClock.elapsedRealtimeNanos() - started) / 1_000_000.0
