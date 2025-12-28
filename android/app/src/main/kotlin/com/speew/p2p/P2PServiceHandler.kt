package com.speew.p2p

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class P2PServiceHandler : Service() {

    private val TAG = "P2PServiceHandler"
    private val NOTIFICATION_CHANNEL_ID = "speew_p2p_channel"
    private val NOTIFICATION_ID = 101
    private val RESTART_WORK_TAG = "P2P_RESTART_WORK"

    // Variáveis de estado crítico
    private var nodeId: String? = null
    private var p2pPort: Int = 0

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created.")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started. Intent: $intent, Flags: $flags")

        // 1. Persistência de Estado Crítico (Auditoria II.2)
        if (intent == null) {
            // Serviço reiniciado pelo SO (ex: START_STICKY ou WorkManager)
            nodeId = SharedPrefsUtil.loadNodeId(this)
            p2pPort = SharedPrefsUtil.loadP2PPort(this)
            
            if (nodeId.isNullOrEmpty() || p2pPort == 0) {
                Log.e(TAG, "CRITICAL: Cannot restart service. State (nodeId/port) not found in SharedPreferences.")
                stopSelf()
                // Auditoria II.1: Agendar WorkManager para nova tentativa de inicialização
                scheduleServiceRestart()
                return START_NOT_STICKY
            }
            Log.i(TAG, "Service restarted successfully. Node ID: $nodeId, Port: $p2pPort")
        } else {
            // Serviço iniciado pelo Flutter/App
            nodeId = intent.getStringExtra("NODE_ID")
            p2pPort = intent.getIntExtra("P2P_PORT", 0)
            
            if (nodeId.isNullOrEmpty() || p2pPort == 0) {
                Log.e(TAG, "CRITICAL: Invalid start intent. Missing NODE_ID or P2P_PORT.")
                stopSelf()
                return START_NOT_STICKY
            }
            
            // Salvar estado crítico para persistência
            SharedPrefsUtil.saveNodeState(this, nodeId!!, p2pPort)
            Log.i(TAG, "Service started by App. State saved.")
        }

        // Lógica de inicialização do P2P (ex: iniciar socket, conectar ao mesh)
        // ...

        // 2. Resiliência do Serviço (Auditoria II.1)
        // Usar START_STICKY para reinicialização simples após queda de memória
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed.")
        // Auditoria II.1: Agendar WorkManager para garantir resiliência total
        scheduleServiceRestart()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    // =================================================================
    // MÉTODOS DE RESILIÊNCIA E PERSISTÊNCIA
    // =================================================================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Speew P2P Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Speew P2P Mesh")
            .setContentText("O serviço de rede está ativo em segundo plano.")
            .setSmallIcon(android.R.drawable.ic_lock_lock) // Ícone placeholder
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    /**
     * Auditoria I.1: Agenda uma tarefa única de WorkManager para reiniciar o serviço
     * após um pequeno atraso, garantindo que o SO não o mate permanentemente.
     */
    private fun scheduleServiceRestart() {
        val restartWork = OneTimeWorkRequestBuilder<P2PRestartWorker>()
            .setInitialDelay(5, TimeUnit.SECONDS)
            .addTag(RESTART_WORK_TAG)
            .build()

        WorkManager.getInstance(this).enqueueUniqueWork(
            RESTART_WORK_TAG,
            ExistingWorkPolicy.REPLACE,
            restartWork
        )
        Log.w(TAG, "WorkManager scheduled to restart P2PService.")
    }
}
