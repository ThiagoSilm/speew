package com.speew.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.PowerManager
import android.util.Log

class EnergyManager(private val context: Context) {
    private val TAG = "SpeewEnergyManager"
    private var powerManager: PowerManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
    enum class EnergyMode {
        LOW_POWER,      // Modo de economia máxima
        BALANCED,       // Modo balanceado (padrão)
        PERFORMANCE     // Modo de alta performance
    }
    
    private var currentMode: EnergyMode = EnergyMode.BALANCED
    
    fun initialize() {
        try {
            powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            Log.d(TAG, "Energy Manager initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Energy Manager", e)
        }
    }
    
    fun getBatteryLevel(): Int {
        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
            context.registerReceiver(null, filter)
        }
        
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        
        return if (level != -1 && scale != -1) {
            (level * 100 / scale.toFloat()).toInt()
        } else {
            -1
        }
    }
    
    fun isCharging(): Boolean {
        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
            context.registerReceiver(null, filter)
        }
        
        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
               status == BatteryManager.BATTERY_STATUS_FULL
    }
    
    fun setEnergyMode(mode: EnergyMode) {
        currentMode = mode
        applyEnergyMode()
        Log.d(TAG, "Energy mode set to: $mode")
    }
    
    private fun applyEnergyMode() {
        when (currentMode) {
            EnergyMode.LOW_POWER -> {
                // Reduzir frequência de sincronização P2P
                // Desabilitar descoberta contínua
                releaseWakeLock()
            }
            EnergyMode.BALANCED -> {
                // Configuração padrão balanceada
                releaseWakeLock()
            }
            EnergyMode.PERFORMANCE -> {
                // Máxima performance, manter CPU ativa
                acquireWakeLock()
            }
        }
    }
    
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Speew::P2PWakeLock"
            )
        }
        
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire(10*60*1000L /*10 minutes*/)
            Log.d(TAG, "WakeLock acquired")
        }
    }
    
    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            Log.d(TAG, "WakeLock released")
        }
    }
    
    fun cleanup() {
        releaseWakeLock()
        Log.d(TAG, "Energy Manager cleaned up")
    }
    
    fun getEnergyStatus(): Map<String, Any> {
        return mapOf(
            "batteryLevel" to getBatteryLevel(),
            "isCharging" to isCharging(),
            "energyMode" to currentMode.name.lowercase()
        )
    }
}
