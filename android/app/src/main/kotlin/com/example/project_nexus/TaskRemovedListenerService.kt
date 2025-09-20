package com.example.project_nexus

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class TaskRemovedListenerService : Service() {
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("TaskRemovedListenerService", "Service started")
        return START_STICKY
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d("TaskRemovedListenerService", "Task removed - app was swiped away")
        
        // Stop the service when the app is removed from recent apps
        stopSelf()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d("TaskRemovedListenerService", "Service destroyed")
    }
}
