package com.example.mobile

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "com.example.mobile/file_intent"
    }

    private var methodChannel: MethodChannel? = null

    private var pendingFilePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        handleIncomingIntent(intent)
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->

            when (call.method) {

                "getInitialFile" -> {
                    result.success(pendingFilePath)
                    pendingFilePath = null
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        /*
         * Android may deliver the file before
         * Flutter finishes initializing.
         *
         * If that happens, deliver it now.
         */
        pendingFilePath?.let { filePath ->

            pendingFilePath = null

            methodChannel?.invokeMethod(
                "fileReceived",
                filePath
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        setIntent(intent)

        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(
        intent: Intent?
    ) {
        if (intent == null) {
            return
        }

        if (
            intent.action != Intent.ACTION_VIEW &&
            intent.action != Intent.ACTION_SEND
        ) {
            return
        }

        val uri: Uri? = when (intent.action) {

            Intent.ACTION_VIEW -> {
                intent.data
            }

            Intent.ACTION_SEND -> {
                if (
                    android.os.Build.VERSION.SDK_INT >=
                    android.os.Build.VERSION_CODES.TIRAMISU
                ) {
                    intent.getParcelableExtra(
                        Intent.EXTRA_STREAM,
                        Uri::class.java
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(
                        Intent.EXTRA_STREAM
                    )
                }
            }

            else -> {
                null
            }
        }

        if (uri == null) {
            return
        }

        val copiedPath = copyIncomingFile(uri)

        if (copiedPath == null) {
            return
        }

        if (methodChannel != null) {

            methodChannel?.invokeMethod(
                "fileReceived",
                copiedPath
            )

        } else {

            pendingFilePath = copiedPath
        }
    }

    private fun copyIncomingFile(
        uri: Uri
    ): String? {

        return try {

            val inputStream =
                contentResolver
                    .openInputStream(uri)
                    ?: return null

            val originalName =
                getFileName(uri)

            /*
             * WhatsApp may provide the file as
             * "Untitled", ".bin", or another generic
             * filename.
             *
             * In those cases always create our own
             * valid Durgasevak filename.
             */
            val safeName =
                if (
                    originalName != null &&
                    originalName
                        .lowercase()
                        .endsWith(".durgasevak")
                ) {
                    originalName
                } else {
                    "durgasevak_import_" +
                        System.currentTimeMillis() +
                        ".durgasevak"
                }

            val destination =
                File(
                    cacheDir,
                    safeName
                )

            inputStream.use { input ->

                destination
                    .outputStream()
                    .use { output ->

                        input.copyTo(output)
                    }
            }

            destination.absolutePath

        } catch (
            e: Exception
        ) {

            null
        }
    }

    private fun getFileName(
        uri: Uri
    ): String? {

        if (uri.scheme == "content") {

            val projection =
                arrayOf(
                    OpenableColumns.DISPLAY_NAME
                )

            contentResolver.query(
                uri,
                projection,
                null,
                null,
                null
            )?.use { cursor ->

                if (cursor.moveToFirst()) {

                    val index =
                        cursor.getColumnIndex(
                            OpenableColumns.DISPLAY_NAME
                        )

                    if (index >= 0) {

                        return cursor.getString(index)
                    }
                }
            }
        }

        return uri.lastPathSegment
    }
}