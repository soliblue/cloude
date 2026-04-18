package com.cloude.app.Services

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.ServiceCompat

class WebSocketForegroundService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        CloudeNotificationManager.createChannels(this)
        ServiceCompat.startForeground(
            this,
            CloudeNotificationManager.NOTIFICATION_SERVICE_ID,
            CloudeNotificationManager.serviceNotification(this),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        )
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}
