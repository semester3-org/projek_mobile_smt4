package com.example.projek_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ngekos/runtime_permissions"
    private val galleryPermissionRequestCode = 4203
    private var pendingGalleryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGalleryPermissionGranted" -> result.success(isGalleryPermissionGranted())
                "requestGalleryPermission" -> requestGalleryPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun galleryPermission(): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun isGalleryPermissionGranted(): Boolean {
        val permission = galleryPermission() ?: return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestGalleryPermission(result: MethodChannel.Result) {
        if (isGalleryPermissionGranted()) {
            result.success(true)
            return
        }
        val permission = galleryPermission()
        if (permission == null) {
            result.success(true)
            return
        }
        pendingGalleryResult?.success(false)
        pendingGalleryResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(arrayOf(permission), galleryPermissionRequestCode)
        } else {
            result.success(true)
            pendingGalleryResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != galleryPermissionRequestCode) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingGalleryResult?.success(granted)
        pendingGalleryResult = null
    }
}
