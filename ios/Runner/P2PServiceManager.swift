import Foundation
import UIKit
import UserNotifications

// Auditoria II.1: Protocolo para Background Fetch
protocol P2PBackgroundDelegate: AnyObject {
    func handleBackgroundFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

class P2PServiceManager: NSObject {
    
    static let shared = P2PServiceManager()
    
    // Constantes de Persistência
    private let NODE_ID_KEY = "speew_node_id"
    private let P2P_PORT_KEY = "speew_p2p_port"
    
    // Variáveis de Estado Crítico
    private var nodeId: String?
    private var p2pPort: Int = 0
    
    // Delegate para o Background Fetch
    weak var backgroundDelegate: P2PBackgroundDelegate?
    
    private override init() {
        super.init()
        // Auditoria II.2: Carregar estado crítico na inicialização
        loadNodeState()
    }
    
    // =================================================================
    // PERSISTÊNCIA DE ESTADO CRÍTICO (Auditoria II.2)
    // =================================================================
    
    /**
     Salva o estado crítico (nodeId e port) no UserDefaults.
     */
    func saveNodeState(nodeId: String, port: Int) {
        UserDefaults.standard.set(nodeId, forKey: NODE_ID_KEY)
        UserDefaults.standard.set(port, forKey: P2P_PORT_KEY)
        self.nodeId = nodeId
        self.p2pPort = port
        print("P2PServiceManager: State saved. Node ID: \(nodeId), Port: \(port)")
    }
    
    /**
     Carrega o estado crítico do UserDefaults.
     */
    func loadNodeState() {
        self.nodeId = UserDefaults.standard.string(forKey: NODE_ID_KEY)
        self.p2pPort = UserDefaults.standard.integer(forKey: P2P_PORT_KEY)
        
        if let id = nodeId, p2pPort != 0 {
            print("P2PServiceManager: State loaded. Node ID: \(id), Port: \(p2pPort)")
            // Iniciar o serviço P2P com o estado recuperado
            startP2PService(nodeId: id, port: p2pPort)
        } else {
            print("P2PServiceManager: Critical state not found. Waiting for Flutter initialization.")
        }
    }
    
    // =================================================================
    // EFICIÊNCIA ENERGÉTICA (Auditoria II.1)
    // =================================================================
    
    /**
     Inicia o serviço P2P.
     */
    func startP2PService(nodeId: String, port: Int) {
        // Lógica de inicialização do socket P2P
        print("P2PServiceManager: P2P Service started with Node ID: \(nodeId) on port \(port)")
        
        // Auditoria II.1: Configurar Background Fetch para manutenção periódica
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        print("P2PServiceManager: Configured minimum background fetch interval.")
    }
    
    /**
     Chamado pelo AppDelegate quando um Background Fetch é acionado.
     */
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("P2PServiceManager: Background Fetch triggered.")
        
        // Auditoria II.1: Lógica de manutenção de baixo consumo
        // 1. Verificar se o serviço P2P está ativo.
        // 2. Se inativo, tentar reativar (com o estado persistido).
        // 3. Realizar uma sincronização de baixo consumo (ex: enviar um ping, verificar CRL).
        
        // Exemplo de lógica de sincronização de baixo consumo:
        if let id = nodeId, p2pPort != 0 {
            print("P2PServiceManager: Performing low-power sync for node \(id)...")
            // Simulação de sincronização
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                print("P2PServiceManager: Low-power sync complete.")
                completionHandler(.newData) // Indica que novos dados foram buscados
            }
        } else {
            print("P2PServiceManager: No critical state, cannot perform sync.")
            completionHandler(.noData)
        }
    }
    
    // =================================================================
    // MÉTODOS DE ACESSO
    // =================================================================
    
    func getCurrentNodeId() -> String? {
        return nodeId
    }
    
    func getCurrentPort() -> Int {
        return p2pPort
    }
}
