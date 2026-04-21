package com.neosapien.assignment.neo_sapien

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the Bonus E native-save Pigeon host API.
        NativeMediaSaverHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            NativeMediaSaverImpl(applicationContext)
        )
    }
}
