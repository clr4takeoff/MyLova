package com.example.emo_diary_spinoff

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.emo_diary_spinoff/data"
    private val PERMISSIONS = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class)
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel() // Notification Channel 생성
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> checkPermissions(result)
                "getSleepData" -> fetchSleepData(result)
                "getStepData" -> fetchStepData(result)
                "getUsageData" -> fetchAppUsageStats(this, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "high_importance_channel"
            val channelName = "High Importance Notifications"
            val descriptionText = "This channel is used for important notifications."
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun checkPermissions(result: MethodChannel.Result) {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)
        CoroutineScope(Dispatchers.IO).launch {
            val grantedPermissions = healthConnectClient.permissionController.getGrantedPermissions()
            if (!grantedPermissions.containsAll(PERMISSIONS)) {
                result.error("PERMISSION_DENIED", "Health permissions not granted", null)
            } else {
                result.success("Permissions granted")
            }
        }
    }

    private fun fetchAppUsageStats(context: Context, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val calendar = Calendar.getInstance()
                val endTime = calendar.timeInMillis
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                val startTime = calendar.timeInMillis

                val queryEvents = usageStatsManager.queryEvents(startTime, endTime)
                val events = UsageEvents.Event()
                val appUsageMap = mutableMapOf<String, AppUsageInfo>()

                while (queryEvents.hasNextEvent()) {
                    queryEvents.getNextEvent(events)
                    if (events.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND || events.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                        val packageName = events.packageName
                        appUsageMap.putIfAbsent(packageName, AppUsageInfo(packageName))
                        val appUsageInfo = appUsageMap[packageName]
                        if (events.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                            appUsageInfo?.lastTimeUsed = events.timeStamp
                        } else if (events.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND && appUsageInfo?.lastTimeUsed != 0L) {
                            appUsageInfo?.addUsage(appUsageInfo.lastTimeUsed, events.timeStamp)
                        }
                    }
                }

                val fetchData = formatAppUsageStats(appUsageMap, context)
                withContext(Dispatchers.Main) { result.success(fetchData) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("ERROR_FETCHING_DATA", e.message, null) }
            }
        }
    }

    private fun formatAppUsageStats(appUsageMap: Map<String, AppUsageInfo>, context: Context): String {
        val stringBuilder = StringBuilder()
        val sortedUsageStats = appUsageMap.entries.sortedByDescending { it.value.totalTimeInForeground }

        sortedUsageStats.take(3).forEach { (packageName, usageInfo) ->
            val usageTimeSeconds = usageInfo.totalTimeInForeground / 1000
            val usageTimeMinutes = usageTimeSeconds / 60 % 60
            val usageTimeHours = usageTimeSeconds / (60 * 60)
            val appName = getAppNameFromPackage(packageName, context)
            if (usageTimeHours > 0) {
                stringBuilder.append("어플 이름: $appName | 사용 시간: ${usageTimeHours}시간 ${usageTimeMinutes}분\n")
            } else {
                stringBuilder.append("어플 이름: $appName | 사용 시간: ${usageTimeMinutes}분\n")
            }
        }
        return stringBuilder.toString()
    }

    private fun fetchSleepData(result: MethodChannel.Result) {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val granted = healthConnectClient.permissionController.getGrantedPermissions()
                if (!granted.containsAll(PERMISSIONS)) {
                    result.error("PERMISSION_DENIED", "Health permissions not granted", null)
                    return@launch
                }

                val endTime = Instant.now()
                val startTime = endTime.minus(Duration.ofDays(1))
                val sleepData = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        recordType = SleepSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )

                val sleepStageStrings = sleepData.records.map {
                    val localStart = it.startTime.atZone(ZoneId.systemDefault())
                    val localEnd = it.endTime.atZone(ZoneId.systemDefault())
                    "$localStart to $localEnd"
                }

                withContext(Dispatchers.Main) {
                    result.success(sleepStageStrings.joinToString("\n"))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("ERROR_FETCHING_DATA", e.message, null) }
            }
        }
    }

    private fun fetchStepData(result: MethodChannel.Result) {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val endTime = Instant.now()
                val startTime = endTime.minus(Duration.ofDays(1))
                val response = healthConnectClient.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                    )
                )

                val stepCount = response[StepsRecord.COUNT_TOTAL] ?: 0
                withContext(Dispatchers.Main) { result.success(stepCount.toString()) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("ERROR_FETCHING_DATA", e.message, null) }
            }
        }
    }

    private fun getAppNameFromPackage(packageName: String, context: Context): String {
        return try {
            val packageManager = context.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    class AppUsageInfo(val packageName: String) {
        var totalTimeInForeground: Long = 0
        var lastTimeUsed: Long = 0

        fun addUsage(startTime: Long, endTime: Long) {
            totalTimeInForeground += endTime - startTime
            lastTimeUsed = endTime
        }
    }
}
