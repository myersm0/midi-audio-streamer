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
	
	// Prevent unused variable warnings by using them in a conditional
	_ = midiManager  // MIDI manager stays alive for callbacks
	
	// Main audio loop
	let bufferSize: UInt32 = 512
	let audioQueue = DispatchQueue(label: "audio.render", qos: .userInteractive)
	
	print("\nAudio streaming started. Play your MIDI device.")
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
