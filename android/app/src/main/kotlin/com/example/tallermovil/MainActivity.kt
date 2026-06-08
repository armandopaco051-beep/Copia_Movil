package com.example.tallermovil

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val audioPickerChannel = "tallermovil/audio_picker"
    private val pickAudioRequestCode = 7102
    private var pendingAudioResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioPickerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAudio" -> pickAudio(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickAudio(result: MethodChannel.Result) {
        if (pendingAudioResult != null) {
            result.error("PICKER_BUSY", "Ya hay un selector de audio abierto.", null)
            return
        }

        pendingAudioResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
        }

        try {
            startActivityForResult(intent, pickAudioRequestCode)
        } catch (e: ActivityNotFoundException) {
            pendingAudioResult = null
            result.error("NO_AUDIO_PICKER", "No se encontro una app para seleccionar audio.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickAudioRequestCode) return

        val result = pendingAudioResult ?: return
        pendingAudioResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            val path = copyAudioToCache(uri)
            result.success(mapOf("path" to path))
        } catch (e: Exception) {
            result.error("AUDIO_COPY_ERROR", "No se pudo preparar el audio seleccionado.", e.message)
        }
    }

    private fun copyAudioToCache(uri: Uri): String {
        val displayName = queryDisplayName(uri) ?: "audio.m4a"
        val safeName = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val target = File(cacheDir, "evidencia_audio_${System.currentTimeMillis()}_$safeName")

        contentResolver.openInputStream(uri).use { input ->
            if (input == null) error("No se pudo abrir el audio seleccionado.")
            FileOutputStream(target).use { output ->
                input.copyTo(output)
            }
        }

        return target.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        var displayName: String? = null
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) displayName = cursor.getString(index)
            }
        }
        return displayName
    }
}
