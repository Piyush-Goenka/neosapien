package com.neosapien.assignment.neo_sapien

import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity (extends FragmentActivity -> ComponentActivity) is used
// instead of FlutterActivity so that `registerForActivityResult` is available —
// needed by the Bonus D native document picker.
class MainActivity : FlutterFragmentActivity() {

    // Bonus D — registered as a field so it is wired before onStart().
    // FlutterActivity extends ComponentActivity, which is what the
    // registerForActivityResult API requires.
    private val filePickerLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            filePicker?.handleResult(result)
        }

    private var filePicker: NativeFilePickerImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        // Bonus E — native save.
        NativeMediaSaverHostApi.setUp(
            binaryMessenger,
            NativeMediaSaverImpl(applicationContext)
        )

        // Bonus D — native document picker.
        val picker = NativeFilePickerImpl(applicationContext, filePickerLauncher)
        filePicker = picker
        NativeFilePickerHostApi.setUp(binaryMessenger, picker)
    }
}
