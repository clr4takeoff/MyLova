package com.example.emo_diary_spinoff

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import java.lang.Exception
import java.util.Calendar

class UsageActivity: FlutterActivity() {

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun fetchAppUsageStats(context: Context, result: MethodChannel.Result){
        CoroutineScope(Dispatchers.IO).launch {
            try {
                var fetchData = ""
                val usageStatsManager =
                    context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

                val calendar = Calendar.getInstance()
                val endTime = calendar.timeInMillis
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                val startTime = calendar.timeInMillis

                val queryUsageStats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY, startTime, endTime
                )

                for (us in queryUsageStats) {
                    if (us.totalTimeInForeground > 0) {
                        val category = getCategory(us.packageName)
                        fetchData += getAppNameJsoup(
                            us.packageName,
                            context
                        ) + "|" + category + "|" + us.totalTimeInForeground + "\n"
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(
                        fetchData
                    )
                }
            } catch (e: Exception){
                withContext(Dispatchers.Main){
                    result.error("ERROR_FETCHING_DATA", e.message, null)
                }
            }
        }
    }

    private fun isAccessGranted(context: Context): Boolean{
        val appOpManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOpManager.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(), context.packageName)
        } else {
            appOpManager.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatePermission(context: Context){
        if(!isAccessGranted(context)){
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            ContextCompat.startActivity(context, intent, null)
        }
    }

    private fun getCategory(packageName: String):String {
        val url = "https://play.google.com/store/apps/details?id=$packageName"
        try {
            val doc: Document = Jsoup.connect(url).get()
            val index = doc.body().data().indexOf("applicationCategory")
            val simpleString = doc.body().data().subSequence(index, index + 100)

            return simpleString.split(":")[1].split(":")[0].split(",")[0]

        } catch (e: Exception){
            return "\"UNKNOWN\""
        }
    }

    private fun getAppNameJsoup(packageName: String, context: Context): String {
        val url = "https://play.google.com/store/apps/details?id=$packageName"
        try {
            val doc: Document = Jsoup.connect(url).get()
            return doc.select("h1").first()?.text().toString()
        } catch (e: Exception){
            return getAppNameFromPackageName(packageName, context)
        }
    }

    private fun getAppNameFromPackageName(packageName: String, context: Context): String {
        val packageManager = context.packageManager
        val appInfo: ApplicationInfo
        try {
            appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        } catch (e: PackageManager.NameNotFoundException) {
            // Handle the exception if the package name is not found
            return getAppNameFromPackage(packageName, context)
        }
        return packageManager.getApplicationLabel(appInfo).toString()
    }

    private fun getAppNameFromPackage(packageName: String, context: Context): String{
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        val pkgAppsList = context.packageManager.queryIntentActivities(mainIntent, 0)

        for (app in pkgAppsList) {
            if (app.activityInfo.packageName.equals(packageName)){
                return app.activityInfo.loadLabel(context.packageManager).toString()
            }
        }
        return packageName
    }
}