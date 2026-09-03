package com.example.convertly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {

    /** Must match the factoryId the Dart side asks for. */
    private val listTileFactoryId = "listTile"

    private var deviceAudio: DeviceAudioChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            listTileFactoryId,
            ListTileNativeAdFactory(layoutInflater)
        )

        deviceAudio = DeviceAudioChannel(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        deviceAudio?.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(
            flutterEngine,
            listTileFactoryId
        )
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
