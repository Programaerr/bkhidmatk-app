package com.jaik.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        useFastestRefreshRate()
    }

    // Many phones (MIUI among them) keep apps at 60 Hz unless the app asks for more, so the
    // app asks for the screen's fastest mode at its current resolution.
    private fun useFastestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
            ?: windowManager.defaultDisplay
            ?: return
        val current = display.mode
        val fastest = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        if (fastest.modeId == current.modeId) return
        window.attributes = window.attributes.apply { preferredDisplayModeId = fastest.modeId }
    }
}
