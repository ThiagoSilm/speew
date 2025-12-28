import Foundation
import UIKit

class EnergyManager {
    enum EnergyMode: String {
        case lowPower = "low_power"
        case balanced = "balanced"
        case performance = "performance"
    }
    
    private var currentMode: EnergyMode = .balanced
    
    func initialize() {
        setupBatteryMonitoring()
        print("EnergyManager: Initialized")
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryLevelDidChange() {
        let level = getBatteryLevel()
        print("EnergyManager: Battery level changed to \(level)%")
        
        // Ajustar modo automaticamente em bateria baixa
        if level < 20 && currentMode != .lowPower {
            setEnergyMode(.lowPower)
        }
    }
    
    @objc private func batteryStateDidChange() {
        print("EnergyManager: Battery state changed")
    }
    
    func getBatteryLevel() -> Int {
        let level = UIDevice.current.batteryLevel
        if level < 0 {
            return -1
        }
        return Int(level * 100)
    }
    
    func isCharging() -> Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }
    
    func setEnergyMode(_ mode: EnergyMode) {
        currentMode = mode
        applyEnergyMode()
        print("EnergyManager: Energy mode set to \(mode.rawValue)")
    }
    
    private func applyEnergyMode() {
        switch currentMode {
        case .lowPower:
            // Reduzir frequência de sincronização P2P
            // Desabilitar descoberta contínua
            print("EnergyManager: Applying low power mode")
        case .balanced:
            // Configuração padrão balanceada
            print("EnergyManager: Applying balanced mode")
        case .performance:
            // Máxima performance
            print("EnergyManager: Applying performance mode")
        }
    }
    
    func getEnergyStatus() -> [String: Any] {
        return [
            "batteryLevel": getBatteryLevel(),
            "isCharging": isCharging(),
            "energyMode": currentMode.rawValue
        ]
    }
    
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isBatteryMonitoringEnabled = false
        print("EnergyManager: Cleaned up")
    }
}
