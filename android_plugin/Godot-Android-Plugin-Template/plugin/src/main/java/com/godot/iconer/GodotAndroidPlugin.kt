package com.godot.iconer

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot) {

    private val executor: ExecutorService = Executors.newFixedThreadPool(4)

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    /**
     * Create icon thumbnails for the given files.
     *
     * @param jsonStr  JSON object: { category: { filePath: md5 } }
     *                 category is one of Picture/Video/Music/Document/Apk/...
     * @param outdir   Directory where the generated PNG icons are stored.
     * @param iconSize Square size of each generated icon. <=0 falls back to 256.
     */
    @UsedByGodot
    fun create_icon(jsonStr: String, outdir: String, iconSize: Int) {
        val size = if (iconSize > 0) iconSize else 256
        val outDir = File(outdir)
        if (!outDir.exists()) outDir.mkdirs()
        try {
            val root = JSONObject(jsonStr)
            val categories = root.keys()
            while (categories.hasNext()) {
                val category = categories.next() as String
                val files = root.optJSONObject(category) ?: continue
                val names = files.keys()
                while (names.hasNext()) {
                    val filePath = names.next() as String
                    val md5 = files.getString(filePath)
                    executor.submit { createOne(category, filePath, md5, outDir, size) }
                }
            }
        } catch (e: Exception) {
            Log.e(pluginName, "create_icon parse failed: ${e.message}")
        }
    }

    private fun createOne(category: String, filePath: String, md5: String, outDir: File, size: Int) {
        val outFile = File(outDir, "$md5.png")
        if (outFile.exists()) return
        try {
            when (category) {
                "Picture" -> createPictureIcon(filePath, outFile, size)
                "Video" -> createVideoIcon(filePath, outFile, size)
                "Music" -> createMusicIcon(outFile, size)
                "Document" -> createDocumentIcon(outFile, size)
                "Apk" -> createApkIcon(outFile, size)
                else -> createDefaultIcon(outFile, size)
            }
            Log.i(pluginName, "icon saved: ${outFile.name}")
        } catch (e: Exception) {
            Log.e(pluginName, "icon failed: $filePath, ${e.message}")
            try { createDefaultIcon(outFile, size) } catch (_: Exception) {}
        }
    }

    // ---------- Picture ----------
    private fun createPictureIcon(path: String, outFile: File, size: Int) {
        val src = decodeSampledBitmap(path, size)
        if (src == null) {
            createDefaultIcon(outFile, size)
            return
        }
        val icon = scaleFit(src, size)
        saveBitmap(icon, outFile)
        if (icon !== src) icon.recycle()
        src.recycle()
    }

    // ---------- Video ----------
    private fun createVideoIcon(path: String, outFile: File, size: Int) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val frame = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            if (frame != null) {
                val icon = scaleFit(frame, size)
                saveBitmap(icon, outFile)
                if (icon !== frame) icon.recycle()
                frame.recycle()
            } else {
                createDefaultIcon(outFile, size)
            }
        } catch (e: Exception) {
            Log.e(pluginName, "video thumb failed: $path, ${e.message}")
            createDefaultIcon(outFile, size)
        } finally {
            retriever.release()
        }
    }

    // ---------- Music: a music note ----------
    private fun createMusicIcon(outFile: File, size: Int) {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBackground(canvas, size)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = WHITE
            textSize = size * 0.45f
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText(MUSIC_NOTE, size / 2f, centerTextBaseline(paint, size / 2f), paint)
        saveBitmap(bmp, outFile)
        bmp.recycle()
    }

    // ---------- Document: a page with text lines ----------
    private fun createDocumentIcon(outFile: File, size: Int) {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBackground(canvas, size)
        val page = RectF(size * 0.16f, size * 0.14f, size * 0.84f, size * 0.86f)
        val pagePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = WHITE }
        canvas.drawRoundRect(page, size * 0.04f, size * 0.04f, pagePaint)
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF9E9E9E.toInt()
            strokeWidth = size * 0.025f
            strokeCap = Paint.Cap.ROUND
        }
        val lineX0 = page.left + size * 0.06f
        val lineX1 = page.right - size * 0.06f
        var y = page.top + size * 0.15f
        val step = size * 0.11f
        for (i in 0 until 5) {
            canvas.drawLine(lineX0, y, lineX1, y, linePaint)
            y += step
        }
        saveBitmap(bmp, outFile)
        bmp.recycle()
    }

    // ---------- Apk: an Android robot ----------
    private fun createApkIcon(outFile: File, size: Int) {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBackground(canvas, size)
        drawAndroidRobot(canvas, size)
        saveBitmap(bmp, outFile)
        bmp.recycle()
    }

    // ---------- Default: a question mark ----------
    private fun createDefaultIcon(outFile: File, size: Int) {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBackground(canvas, size)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = WHITE
            textSize = size * 0.5f
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("?", size / 2f, centerTextBaseline(paint, size / 2f), paint)
        saveBitmap(bmp, outFile)
        bmp.recycle()
    }

    // ---------- drawing helpers ----------
    private fun drawBackground(canvas: Canvas, size: Int) {
        val paint = Paint().apply { color = BG_COLOR }
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
    }

    private fun centerTextBaseline(paint: Paint, centerY: Float): Float {
        val fm = paint.fontMetrics
        return centerY - (fm.ascent + fm.descent) / 2f
    }

    private fun drawAndroidRobot(canvas: Canvas, size: Int) {
        val headRadius = size * 0.20f
        val cx = size / 2f
        val headCenterY = size * 0.38f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ANDROID_GREEN }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ANDROID_GREEN
            strokeWidth = size * 0.025f
            strokeCap = Paint.Cap.ROUND
        }
        // antennae
        canvas.drawLine(
            cx - headRadius * 0.5f, headCenterY - headRadius,
            cx - headRadius * 0.95f, headCenterY - headRadius - size * 0.08f, stroke
        )
        canvas.drawLine(
            cx + headRadius * 0.5f, headCenterY - headRadius,
            cx + headRadius * 0.95f, headCenterY - headRadius - size * 0.08f, stroke
        )
        // head dome
        val head = Path()
        head.moveTo(cx - headRadius, headCenterY)
        head.arcTo(RectF(cx - headRadius, headCenterY - headRadius, cx + headRadius, headCenterY + headRadius), 180f, 180f, false)
        head.close()
        canvas.drawPath(head, fill)
        // eyes
        val eye = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = WHITE }
        val eyeR = size * 0.018f
        canvas.drawCircle(cx - headRadius * 0.45f, headCenterY - headRadius * 0.15f, eyeR, eye)
        canvas.drawCircle(cx + headRadius * 0.45f, headCenterY - headRadius * 0.15f, eyeR, eye)
        // body
        val bodyTop = headCenterY + size * 0.05f
        val bodyW = headRadius * 0.8f
        val body = RectF(cx - bodyW, bodyTop, cx + bodyW, size * 0.90f)
        canvas.drawRoundRect(body, size * 0.03f, size * 0.03f, fill)
        // arm gap cutouts
        val gap = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BG_COLOR }
        canvas.drawRoundRect(cx - bodyW * 1.25f, bodyTop + size * 0.05f, cx - bodyW * 0.85f, bodyTop + size * 0.28f, size * 0.02f, size * 0.02f, gap)
        canvas.drawRoundRect(cx + bodyW * 0.85f, bodyTop + size * 0.05f, cx + bodyW * 1.25f, bodyTop + size * 0.28f, size * 0.02f, size * 0.02f, gap)
    }

    // ---------- bitmap helpers ----------
    private fun decodeSampledBitmap(path: String, reqSize: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= reqSize && bounds.outHeight / (sample * 2) >= reqSize) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(path, opts)
    }

    private fun scaleFit(src: Bitmap, maxSize: Int): Bitmap {
        val w = src.width
        val h = src.height
        if (w <= 0 || h <= 0) return src
        val scale = minOf(maxSize.toFloat() / w, maxSize.toFloat() / h)
        val outW = (w * scale).toInt().coerceAtLeast(1)
        val outH = (h * scale).toInt().coerceAtLeast(1)
        val scaled = Bitmap.createScaledBitmap(src, outW, outH, true)
        val canvas = Bitmap.createBitmap(maxSize, maxSize, Bitmap.Config.ARGB_8888)
        val c = Canvas(canvas)
        c.drawColor(BG_COLOR)
        c.drawBitmap(scaled, (maxSize - outW) / 2f, (maxSize - outH) / 2f, null)
        return canvas
    }

    private fun saveBitmap(bmp: Bitmap, outFile: File) {
        FileOutputStream(outFile).use { fos ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
            fos.flush()
        }
    }

    companion object {
        private const val WHITE = 0xFFFFFFFF.toInt()
        private const val BG_COLOR = 0xFF3A3A3A.toInt()
        private const val ANDROID_GREEN = 0xFF3DDC84.toInt()
        private const val MUSIC_NOTE = "\u266A"
    }
}
