package com.cloude.app.Services

import android.util.Log

object SwiftBridge {
    private var loaded = false

    fun initialize() {
        if (loaded) return
        try {
            System.loadLibrary("CloudeAndroidBridge")
            System.loadLibrary("swift_bridge")
            loaded = true
            Log.i("SwiftBridge", "Swift bridge loaded, version: ${bridgeVersion()}")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("SwiftBridge", "Failed to load Swift bridge: ${e.message}")
        }
    }

    fun encodeClientMessage(json: String): String? {
        if (!loaded) return null
        return nativeEncodeClientMessage(json)
    }

    fun decodeServerMessage(json: String): String? {
        if (!loaded) return null
        return nativeDecodeServerMessage(json)
    }

    fun bridgeVersion(): String? {
        if (!loaded) return null
        return nativeBridgeVersion()
    }

    private external fun nativeEncodeClientMessage(json: String): String?
    private external fun nativeDecodeServerMessage(json: String): String?
    private external fun nativeBridgeVersion(): String?
}
