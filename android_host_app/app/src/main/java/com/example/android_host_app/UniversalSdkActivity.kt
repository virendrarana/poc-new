package com.example.android_host_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class UniversalSdkActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_EVENTS = "universal_experience_sdk/events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EVENTS)
            .setMethodCallHandler { call, result ->
                if (call.method == "onKycEvent") {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val type = args["type"] as? String ?: "unknown"
                        val step = args["step"] as? String
                        val message = args["message"] as? String ?: ""
                        val timestamp = (args["timestamp"] as? Number)?.toLong()
                            ?: System.currentTimeMillis()
                        val metaMap = args["meta"] as? Map<*, *>
                        val metaString = metaMap?.toString()

                        val entry = KycLogStore.LogEntry(
                            type = type,
                            step = step,
                            message = message,
                            meta = metaString,
                            timestampMillis = timestamp
                        )

                        KycLogStore.add(entry)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
