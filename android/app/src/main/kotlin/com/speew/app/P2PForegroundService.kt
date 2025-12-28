package com.speew.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

// Ponto 4: Implementar Networking Real (Android - Kotlin/ServerSocket) e Power Management (Wakelock)
class P2PForegroundService : Service() {
    private val TAG = "SpeewP2PService"
    private val NOTIFICATION_CHANNEL_ID = "speew_p2p_channel"
    private val NOTIFICATION_ID = 101
    private val P2P_PORT = 8888 // Porta de escuta P2P
    
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private lateinit var executorService: ExecutorService
    private lateinit var wakeLock: PowerManager.WakeLock
    
    // Referência ao MethodChannel para chamar o Dart (Handshake)
    private lateinit var channel: MethodChannel

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        executorService = Executors.newCachedThreadPool()
        
        // Inicialização do MethodChannel (assumindo que o FlutterEngine já está rodando)
        // Na implementação real, o MethodChannel seria passado pelo P2PServiceManager
        // Simulação:
        // channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "speew/p2p_service_manager")
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Speew::P2PServiceWakelock"
        ).apply {
            acquire()
            Log.d(TAG, "Wakelock acquired")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == P2PServiceManager.ACTION_START_FOREGROUND_SERVICE) {
            startForeground(NOTIFICATION_ID, createNotification())
            if (!isRunning) {
                isRunning = true
                startP2PListener()
            }
        } else if (intent?.action == P2PServiceManager.ACTION_STOP_FOREGROUND_SERVICE) {
            stopP2PListener()
            stopForeground(true)
            stopSelf()
        }
        return START_STICKY
    }

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Speew P2P Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
        
        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Speew P2P Ativo")
            .setContentText("O serviço de rede P2P está rodando em segundo plano.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
    }

    private fun startP2PListener() {
        executorService.execute {
            try {
                serverSocket = ServerSocket(P2P_PORT)
                Log.i(TAG, "P2P ServerSocket listening on port $P2P_PORT")
                
                while (isRunning) {
                    try {
                        val clientSocket = serverSocket?.accept()
                        if (clientSocket != null) {
                            Log.d(TAG, "New connection from: ${clientSocket.inetAddress.hostAddress}")
                            // Inicia o ConnectionHandler para o Handshake
                            executorService.execute(ConnectionHandler(clientSocket))
                        }
                    } catch (e: IOException) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting connection: ${e.message}")
                            // Ponto 7: Error Handling - Tentar reconnect automaticamente
                            Thread.sleep(5000)
                        }
                    }
                }
            } catch (e: IOException) {
                Log.e(TAG, "Could not start ServerSocket on port $P2P_PORT: ${e.message}")
                isRunning = false
            }
        }
    }

    private fun stopP2PListener() {
        isRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
            Log.i(TAG, "P2P ServerSocket closed")
        } catch (e: IOException) {
            Log.e(TAG, "Error closing ServerSocket: ${e.message}")
        }
        executorService.shutdownNow()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopP2PListener()
        if (wakeLock.isHeld) {
            wakeLock.release()
            Log.d(TAG, "Wakelock released")
        }
        Log.d(TAG, "Service onDestroy")
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    // Handler para cada conexão de peer
    private inner class ConnectionHandler(private val socket: Socket) : Runnable {
        override fun run() {
            try {
                // 1. Iniciar Handshake Criptográfico (Chamada ao Dart)
                // O Dart (SecureChannelService) deve ser chamado para orquestrar a troca de chaves
                
                // Simulação:
                // val sessionKey = channel.invokeMethod("performHandshake", mapOf("socketAddress" to socket.inetAddress.hostAddress))
                
                // Se o Handshake for bem-sucedido, o socket está criptografado
                Log.i(TAG, "Handshake successful with ${socket.inetAddress.hostAddress}. Tunnel secured.")
                
                // 2. Lógica de Comunicação Criptografada
                val input = socket.getInputStream()
                val output = socket.getOutputStream()
                
                // TODO: Usar a chave de sessão para criptografar/descriptografar o tráfego
                
                // Exemplo de leitura:
                val buffer = ByteArray(1024)
                val bytesRead = input.read(buffer)
                if (bytesRead > 0) {
                    // Aqui, o dado lido deve ser DESCRIPTOGRAFADO antes de ser enviado ao Dart
                    val encryptedMessage = String(buffer, 0, bytesRead)
                    Log.d(TAG, "Received ENCRYPTED message: $encryptedMessage")
                    
                    // Simulação: Chamar o Dart para processar a mensagem
                    // channel.invokeMethod("processEncryptedMessage", mapOf("data" to encryptedMessage))
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Handshake or Connection error with ${socket.inetAddress.hostAddress}: ${e.message}")
            } finally {
                try {
                    socket.close()
                } catch (e: IOException) {
                    Log.e(TAG, "Error closing client socket: ${e.message}")
                }
            }
        }
    }
}
