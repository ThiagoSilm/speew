import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var p2pManager: P2PManager?
    private var energyManager: EnergyManager?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        methodChannel = FlutterMethodChannel(
            name: "com.speew.app/native",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "initP2P":
                self?.initializeP2PServices()
                result("P2P initialized")
            case "getEnergyStatus":
                if let status = self?.energyManager?.getEnergyStatus() {
                    result(status)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "Energy manager not initialized", details: nil))
                }
            case "setEnergyMode":
                if let modeString = call.arguments as? String,
                   let mode = EnergyManager.EnergyMode(rawValue: modeString) {
                    self?.energyManager?.setEnergyMode(mode)
                    result("Energy mode set")
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid energy mode", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        initializeP2PServices()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func initializeP2PServices() {
        p2pManager = P2PManager()
        p2pManager?.initialize()
        
        energyManager = EnergyManager()
        energyManager?.initialize()
        
        // Configuração de Background Tasks para Energy Manager
        if #available(iOS 13.0, *) {
            // BGTaskScheduler será configurado aqui
        }
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        // Manter serviços P2P ativos em background
        // Implementar CXProviderDelegate para simular chamada VoIP e evitar encerramento do processo
        // Exemplo: p2pManager?.startVoIPKeepAlive()
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        // Reativar serviços P2P completos
        // Exemplo: p2pManager?.stopVoIPKeepAlive()
    }
}
