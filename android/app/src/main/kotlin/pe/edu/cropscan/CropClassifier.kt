package pe.edu.cropscan

import android.content.res.AssetManager
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import org.json.JSONObject
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

internal class CropClassifier(private val assets: AssetManager) {
    fun analyze(photo: ByteArray, prototype: Boolean): Map<String, Any> {
        val threshold = if (prototype) 0.60 else assets.open("cropscan-model.json").bufferedReader().use {
            JSONObject(it.readText()).getDouble("threshold")
        }
        require(threshold.isFinite() && threshold in 0.5..1.0)
        val modelFile = if (prototype) "crop-visual-prototype.tflite" else "cropscan.tflite"
        val model = assets.open(modelFile).use { it.readBytes() }
        val modelBuffer = ByteBuffer.allocateDirect(model.size).order(ByteOrder.nativeOrder())
        modelBuffer.put(model).rewind()

        return Interpreter(modelBuffer, Interpreter.Options().setNumThreads(2)).use { interpreter ->
            require(interpreter.inputTensorCount == 1 && interpreter.outputTensorCount == 1)
            val input = interpreter.getInputTensor(0)
            val output = interpreter.getOutputTensor(0)
            val shape = input.shape()
            require(input.dataType() == DataType.FLOAT32 && shape.size == 4 &&
                shape[0] == 1 && shape[1] > 0 && shape[2] > 0 && shape[3] == 3)
            require(output.dataType() == DataType.FLOAT32 &&
                output.shape().contentEquals(intArrayOf(1, 2)))

            val scores = Array(1) { FloatArray(2) }
            interpreter.run(cropImageInput(photo, shape[2], shape[1], input.numBytes()), scores)
            val (noVisibleSigns, possibleScale) = scores.single()
            require(noVisibleSigns in 0f..1f && possibleScale in 0f..1f &&
                abs(noVisibleSigns + possibleScale - 1f) < 0.001f)
            val hasPossibleScale = possibleScale > noVisibleSigns
            mapOf(
                "category" to if (hasPossibleScale) "possible_scale" else "no_visible_signs",
                "confidence" to maxOf(noVisibleSigns, possibleScale).toDouble(),
                "threshold" to threshold,
            )
        }
    }

}

internal fun cropImageInput(photo: ByteArray, width: Int, height: Int, byteCount: Int): ByteBuffer {
    val source = ImageDecoder.createSource(ByteBuffer.wrap(photo))
    val bitmap = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
        decoder.setTargetSize(width, height)
    }
    val pixels = IntArray(width * height)
    try {
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
    } finally {
        bitmap.recycle()
    }
    val input = ByteBuffer.allocateDirect(byteCount).order(ByteOrder.nativeOrder())
    for (pixel in pixels) {
        input.putFloat(((pixel shr 16) and 0xff).toFloat())
        input.putFloat(((pixel shr 8) and 0xff).toFloat())
        input.putFloat((pixel and 0xff).toFloat())
    }
    input.rewind()
    return input
}
