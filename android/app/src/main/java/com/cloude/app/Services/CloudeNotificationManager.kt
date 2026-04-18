package com.cloude.app.Services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.cloude.app.App.MainActivity
import com.cloude.app.R

object CloudeNotificationManager {
    const val CHANNEL_SERVICE = "cloude_service"
    const val CHANNEL_AGENT = "cloude_agent"
    const val NOTIFICATION_SERVICE_ID = 1
    private var nextNotificationId = 100

    fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SERVICE,
                "Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Keeps the WebSocket connection alive in the background" }
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_AGENT,
                "Agent Events",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Agent completion, errors, and permission requests" }
        )
    }

    fun serviceNotification(context: Context) =
        NotificationCompat.Builder(context, CHANNEL_SERVICE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Cloude")
            .setContentText("Connection active")
            .setOngoing(true)
            .build()

    private fun launchIntent(context: Context) = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    fun notifyAgentComplete(context: Context, conversationName: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(
            nextNotificationId++,
            NotificationCompat.Builder(context, CHANNEL_AGENT)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Task complete")
                .setContentText(conversationName)
                .setContentIntent(launchIntent(context))
                .setAutoCancel(true)
                .build()
        )
    }

    fun notifyAgentError(context: Context, message: String) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(
            nextNotificationId++,
            NotificationCompat.Builder(context, CHANNEL_AGENT)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Agent error")
                .setContentText(message)
                .setContentIntent(launchIntent(context))
                .setAutoCancel(true)
                .build()
        )
    }
}
