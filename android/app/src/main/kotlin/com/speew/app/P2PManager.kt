package com.speew.app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

// Nomenclatura corrigida para P2PServiceManager
class P2PServiceManager(private val context: Context) {
    private val TAG = "SpeewP2PServiceManager"
    
    // Ação de serviço em primeiro plano (Foreground Service)
    companion object {
        const val ACTION_START_FOREGROUND_SERVICE = "ACTION_START_FOREGROUND_SERVICE"
        const val ACTION_STOP_FOREGROUND_SERVICE = "ACTION_STOP_FOREGROUND_SERVICE"
    }

    fun initialize() {
        Log.d(TAG, "P2PServiceManager initialized")
    }
    
    fun startForegroundService() {
        val intent = Intent(context, P2PForegroundService::class.java)
        intent.action = ACTION_START_FOREGROUND_SERVICE
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        Log.d(TAG, "Foreground P2P service started with action: $ACTION_START_FOREGROUND_SERVICE")
    }
    
    fun stopForegroundService() {
        val intent = Intent(context, P2PForegroundService::class.java)
        intent.action = ACTION_STOP_FOREGROUND_SERVICE
        context.startService(intent)
        Log.d(TAG, "Foreground P2P service stopped")
    }
    
    fun cleanup() {
        stopForegroundService()
        Log.d(TAG, "P2P services cleaned up")
    }
}

// O serviço em primeiro plano está em P2PForegroundService.kt
// Este arquivo deve ser criado separadamente, mas o manager é o ponto de contato
// class P2PForegroundService : Service() { ... }
