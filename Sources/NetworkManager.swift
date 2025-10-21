import Foundation
import Darwin

class NetworkManager {
	private var fileHandle: FileHandle?
	private var isConnected = false
	private let config: Config
	
	init(config: Config) {
		self.config = config
		setupConnection()
	}
	
	private func setupConnection() {
		let pipePath = "/tmp/audio_pipe"
		
		// Create named pipe if it doesn't exist
		let fileManager = FileManager.default
		if !fileManager.fileExists(atPath: pipePath) {
			let result = mkfifo(pipePath, 0o666)
			if result == 0 {
				print("Created named pipe at \(pipePath)")
			} else {
				print("Warning: Could not create named pipe: \(String(cString: strerror(errno)))")
			}
		}
		
		print("Opening pipe for writing (will block until Julia opens for reading)...")
		
		// Open pipe for writing (this blocks until reader connects)
		if let handle = FileHandle(forWritingAtPath: pipePath) {
			self.fileHandle = handle
			self.isConnected = true
			print("✓ Pipe opened successfully")
		} else {
			print("✗ Failed to open pipe")
		}
	}
	
	func sendAudioData(_ data: Data) {
		guard isConnected, let handle = fileHandle else {
			verboseLog("Cannot send - not connected")
			return
		}
		
		do {
			// Write directly to the pipe
			try handle.write(contentsOf: data)
			verboseLog("Wrote \(data.count) bytes to pipe")
		} catch {
			verboseLog("Write error: \(error)")
			isConnected = false
		}
	}
	
	var connectionStatus: Bool {
		return isConnected
	}
	
	deinit {
		try? fileHandle?.close()
	}
}
