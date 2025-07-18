import Network
import Foundation

class NetworkManager {
	private let connection: NWConnection
	private var isConnected = false
	
	init(config: Config) {
		self.connection = NWConnection(
			host: NWEndpoint.Host(config.host),
			port: NWEndpoint.Port(integerLiteral: UInt16(config.port)),
			using: .tcp
		)
		
		setupConnection()
	}
	
	private func setupConnection() {
		connection.stateUpdateHandler = { [weak self] state in
			print("TCP connection state: \(state)")
			
			switch state {
			case .ready:
				self?.isConnected = true
				print("Connected to Julia client")
			case .failed(let error):
				self?.isConnected = false
				print("Connection failed: \(error)")
			case .cancelled:
				self?.isConnected = false
				print("Connection cancelled")
			default:
				verboseLog("Connection state changed to: \(state)")
			}
		}
		
		connection.start(queue: .global())
	}
	
	func sendAudioData(_ data: Data) {
		guard isConnected else { return }
		
		connection.send(content: data, completion: .contentProcessed { error in
			if let error = error {
				verboseLog("Send error: \(error)")
			}
		})
	}
	
	var connectionStatus: Bool {
		return isConnected
	}
	
	deinit {
		connection.cancel()
	}
}
