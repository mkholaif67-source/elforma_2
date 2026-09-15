package com.elforma.elforma

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max

class MainActivity : FlutterFragmentActivity() {
    private val healthPermissions = setOf(HealthPermission.getReadPermission(StepsRecord::class))
    private var permissionResult: MethodChannel.Result? = null

    private val sensorPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) startStepCounterListener()
        permissionResult?.success(mapOf("status" to if (granted) "ready" else "sensor_permission"))
        permissionResult = null
    }

    private val healthPermissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        if (granted.containsAll(healthPermissions)) {
            requestSensorPermissionOrFinish()
        } else {
            // Health Connect is not mandatory; continue with the phone sensor.
            requestSensorPermissionOrFinish()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        startStepCounterListener()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elforma/steps")
            .setMethodCallHandler { call, result ->
                if (call.method == "settings") {
                    try {
                        val intent = if (HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE)
                            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
                        else Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata"))
                        startActivity(intent)
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("unavailable", "Health Connect settings unavailable", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "read" && call.method != "readLocal" && call.method != "request") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.method == "request") {
                    requestStepAccess(result)
                    return@setMethodCallHandler
                }
                readSteps(result, includeHealth = call.method == "read")
            }
    }

    private fun requestStepAccess(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("busy", "Permission request pending", null)
            return
        }
        permissionResult = result
        val healthStatus = healthStatus()
        if (healthStatus == HealthConnectClient.SDK_AVAILABLE) {
            lifecycleScope.launch {
                try {
                    val client = HealthConnectClient.getOrCreate(this@MainActivity)
                    if (!client.permissionController.getGrantedPermissions().containsAll(healthPermissions)) {
                        healthPermissionLauncher.launch(healthPermissions)
                    } else {
                        requestSensorPermissionOrFinish()
                    }
                } catch (_: Exception) {
                    // Health Connect is optional: the phone step counter can still work alone.
                    requestSensorPermissionOrFinish()
                }
            }
        } else {
            requestSensorPermissionOrFinish()
        }
    }

    private fun requestSensorPermissionOrFinish() {
        if (!hasStepCounter()) {
            permissionResult?.success(mapOf("status" to "ready"))
            permissionResult = null
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
        ) {
            startStepCounterListener()
            permissionResult?.success(mapOf("status" to "ready"))
            permissionResult = null
        } else {
            sensorPermissionLauncher.launch(Manifest.permission.ACTIVITY_RECOGNITION)
        }
    }

    private fun readSteps(result: MethodChannel.Result, includeHealth: Boolean = true) {
        lifecycleScope.launch {
            try {
                val zone = ZoneId.systemDefault()
                val today = LocalDate.now(zone)
                StepTrackingService.startIfAllowed(this@MainActivity)
                val days = StepTrackingStore.recentDays(this@MainActivity, today).toMutableList()
                var healthUsed = false
                var healthNeedsPermission = false

                // Health Connect is only an optional local merge. Home-card refreshes use
                // readLocal, so steps never wait for network or seven aggregate queries.
                if (includeHealth && healthStatus() == HealthConnectClient.SDK_AVAILABLE) {
                    try {
                        val client = HealthConnectClient.getOrCreate(this@MainActivity)
                        if (client.permissionController.getGrantedPermissions().containsAll(healthPermissions)) {
                            for (entry in days) {
                                val day = LocalDate.parse(entry["day"] as String)
                                val healthCount = client.aggregate(
                                    AggregateRequest(
                                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                                        timeRangeFilter = TimeRangeFilter.between(
                                            day.atStartOfDay(zone).toInstant(),
                                            day.plusDays(1).atStartOfDay(zone).toInstant()
                                        )
                                    )
                                )[StepsRecord.COUNT_TOTAL]
                                if (healthCount != null) {
                                    val local = (entry["count"] as? Number)?.toLong()
                                    entry["count"] = local?.let { max(it, healthCount) } ?: healthCount
                                    healthUsed = true
                                }
                            }
                        } else healthNeedsPermission = true
                    } catch (_: Exception) { /* local sensor data remains available */ }
                }

                val sensorGranted = StepTrackingService.permissionGranted(this@MainActivity)
                val hasSensor = StepTrackingService.hasSensor(this@MainActivity)
                val todayReading = (days.lastOrNull()?.get("count") as? Number)?.toLong()
                val status = when {
                    hasSensor && !sensorGranted -> "sensor_permission"
                    todayReading != null || healthUsed -> "ready"
                    healthNeedsPermission && !hasSensor -> "permission"
                    healthStatus() == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED && !hasSensor -> "install"
                    healthStatus() == HealthConnectClient.SDK_UNAVAILABLE && !hasSensor -> "unsupported"
                    else -> "ready"
                }
                result.success(mapOf(
                    "status" to status,
                    "days" to days,
                    "source" to when {
                        hasSensor && healthUsed -> "health_connect+device"
                        hasSensor -> "device"
                        healthUsed -> "health_connect"
                        else -> "none"
                    },
                    "trackingStart" to StepTrackingStore.startDate(this@MainActivity, today).toString(),
                    "background" to (hasSensor && sensorGranted),
                    "updatedAt" to java.time.Instant.now().toString()
                ))
            } catch (_: SecurityException) {
                result.success(mapOf("status" to "sensor_permission"))
            } catch (_: Exception) {
                result.error("steps_unavailable", "Could not read steps. Try again.", null)
            }
        }
    }

    private fun healthStatus(): Int =
        if (Build.VERSION.SDK_INT < 28) HealthConnectClient.SDK_UNAVAILABLE
        else HealthConnectClient.getSdkStatus(this)

    private fun hasStepCounter(): Boolean = StepTrackingService.hasSensor(this)

    private fun startStepCounterListener() {
        StepTrackingService.startIfAllowed(this)
    }
}
