package com.speew.p2p

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class P2PRestartWorker(appContext: Context, workerParams: WorkerParameters) : Worker(appContext, workerParams) {

    private val TAG = "P2PRestartWorker"

    override fun doWork(): Result {
        Log.i(TAG, "Attempting to restart P2PServiceHandler...")
        
        // O WorkManager reinicia o serviço. O onStartCommand do serviço
        // irá verificar se o estado crítico está no SharedPreferences.
        try {
            val serviceIntent = Intent(applicationContext, P2PServiceHandler::class.java)
            applicationContext.startService(serviceIntent)
            Log.i(TAG, "P2PServiceHandler started successfully.")
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start P2PServiceHandler: ${e.message}")
            // Se falhar, tentar novamente mais tarde (retry)
            return Result.retry()
        }
    }
}
