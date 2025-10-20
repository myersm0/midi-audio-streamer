import Foundation
import Dispatch

print("Starting AudioUnitHost")

// Parse configuration
globalConfig = Config.parse()
verboseLog("Configuration: subtype=\(globalConfig.componentSubType), manufacturer=\(globalConfig.componentManufacturer)")

do {
	// Initialize audio unit manager
	let audioUnitManager = try AudioUnitManager(config: globalConfig)
	
	// Initialize MIDI manager (keep reference to prevent deallocation)
	let midiManager = try MIDIManager(audioUnitManager: audioUnitManager)
	
	// Initialize network manager
	let networkManager = NetworkManager(config: globalConfig)
	
	// Optionally initialize RPC client
	var rpcClient: ModarttRPC?
	if globalConfig.rpcEnabled {
		rpcClient = ModarttRPC(host: globalConfig.rpcHost, port: globalConfig.rpcPort)
		
		if let info = rpcClient?.getInfo() {
			print("\nConnected to RPC server:")
			if let productName = info["product_name"] as? String {
				print("  Product: \(productName)")
			}
			if let version = info["version"] as? String {
				print("  Version: \(version)")
			}
			if let preset = info["current_preset"] as? [String: Any],
			   let name = preset["name"] as? String {
				print("  Current Preset: \(name)")
			}
			
			verboseLog("Starting RPC monitoring thread...")
			
			// Start RPC monitoring thread
			let rpcQueue = DispatchQueue(label: "rpc.monitor", qos: .background)
			rpcQueue.async {
				var lastPresetName: String?
				var lastParameters: [[String: Any]]?
				
				while true {
					Thread.sleep(forTimeInterval: 0.5)
					
					verboseLog("Polling RPC server...")
					
					if let info = rpcClient?.getInfo() {
						verboseLog("Got info from RPC server")
						
						if let preset = info["current_preset"] as? [String: Any],
						   let name = preset["name"] as? String {
							if name != lastPresetName {
								print("\n[RPC] Preset changed to: \(name)")
								lastPresetName = name
								lastParameters = nil
							}
						}
					}
					
					if let currentParams = rpcClient?.getParameters() {
						if let lastParams = lastParameters {
							let changes = rpcClient?.compareParameters(old: lastParams, new: currentParams) ?? []
							
							for change in changes {
								if let id = change["id"] as? String,
								   let name = change["name"] as? String,
								   let text = change["text"] as? String {
									print("[RPC] Parameter changed: \(name) = \(text) (id: \(id))")
								}
							}
						}
						
						lastParameters = currentParams
					} else {
						verboseLog("Failed to get parameters from RPC server")
					}
				}
			}
		} else {
			print("\nWarning: Could not connect to RPC server at \(globalConfig.rpcHost):\(globalConfig.rpcPort)")
		}
	}
	
	// Prevent unused variable warnings by using them in a conditional
	_ = midiManager  // MIDI manager stays alive for callbacks
	_ = rpcClient  // RPC client stays alive if enabled
	
	// Main audio loop
	let bufferSize = globalConfig.bufferSize
	let audioQueue = DispatchQueue(label: "audio.render", qos: .userInteractive)
	
	print("\nAudio streaming started. Play your MIDI device!")
	print("Press Ctrl+C to stop.\n")
	
	audioQueue.async {
		while true {
			autoreleasepool {
				if let audioData = audioUnitManager.renderAudio(frames: bufferSize) {
					networkManager.sendAudioData(audioData)
				}
			}
			
			// Sleep for approximately 11.6ms (44.1kHz sample rate with 512 frames)
			usleep(11600)
		}
	}
	
	// Keep the main thread alive
	RunLoop.main.run()
	
} catch {
	print("Error: \(error.localizedDescription)")
	exit(1)
}
