package com.speew.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.speew.app/native"
    private lateinit var p2pManager: P2PManager
    private lateinit var energyManager: EnergyManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initializeP2PServices()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initP2P" -> {
                    try {
                        initializeP2PServices()
                        result.success("P2P initialized")
                    } catch (e: Exception) {
                        result.error("P2P_ERROR", e.message, null)
                    }
                }
                "getEnergyStatus" -> {
                    result.success(energyManager.getEnergyStatus())
                }
                "setEnergyMode" -> {
                    val mode = call.argument<String>("mode")
                    when (mode) {
                        "low_power" -> energyManager.setEnergyMode(EnergyManager.EnergyMode.LOW_POWER)
                        "balanced" -> energyManager.setEnergyMode(EnergyManager.EnergyMode.BALANCED)
                        "performance" -> energyManager.setEnergyMode(EnergyManager.EnergyMode.PERFORMANCE)
                    }
                    result.success("Energy mode set")
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun initializeP2PServices() {
        p2pManager = P2PManager(this)
        p2pManager.initialize()
        
        energyManager = EnergyManager(this)
        energyManager.initialize()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        p2pManager.cleanup()
        energyManager.cleanup()
    }
}
