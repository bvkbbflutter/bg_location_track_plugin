package com.example.bg_location_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject

object NotificationFactory {
    fun createNotification(
        context: Context,
        optionsJson: String,
        contentText: String? = null
    ): android.app.Notification {
        val options = try {
            JSONObject(optionsJson)
        } catch (e: Exception) {
            JSONObject()
        }

        val channelId = options.optString("channelId", "tracking_channel")
        val channelName = options.optString("channelName", "Location Tracking")
        val title = options.optString("title", "Tracking Active")
        val text = contentText ?: options.optString("text", "Your location is being recorded in the background.")
        val smallIconResName = options.optString("smallIconResName", "ic_notification")
        val tapOpensApp = options.optBoolean("tapOpensApp", true)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Location tracking service"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val resId = context.resources.getIdentifier(smallIconResName, "drawable", context.packageName).let {
            if (it == 0) android.R.drawable.ic_menu_mylocation else it
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(resId)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)

        if (tapOpensApp) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)
                builder.setContentIntent(pendingIntent)
            }
        }

        return builder.build()
    }
}
