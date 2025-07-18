import CoreMIDI
import Foundation

class MIDIManager {
	private var midiClient = MIDIClientRef()
	private var midiInputPort = MIDIPortRef()
	private weak var audioUnitManager: AudioUnitManager?
	
	init(audioUnitManager: AudioUnitManager) throws {
		self.audioUnitManager = audioUnitManager
		let clientStatus = MIDIClientCreate("AudioUnitHost" as CFString, nil, nil, &midiClient)
		guard clientStatus == noErr else {
			throw MIDIError.clientCreationFailed(status: clientStatus)
		}
		
		let portStatus = MIDIInputPortCreate(
			midiClient,
			"Input" as CFString,
			midiInputCallback,
			Unmanaged.passUnretained(self).toOpaque(),
			&midiInputPort
		)
		guard portStatus == noErr else {
			throw MIDIError.portCreationFailed(status: portStatus)
		}
		
		connectToAllSources()
	}
	
	private func connectToAllSources() {
		let sourceCount = MIDIGetNumberOfSources()
		print("\nFound \(sourceCount) MIDI sources:")
		
		for i in 0..<sourceCount {
			let source = MIDIGetSource(i)
			var name: Unmanaged<CFString>?
			MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
			
			if let name = name {
				print("  - \(name.takeRetainedValue())")
			}
			
			let connectStatus = MIDIPortConnectSource(midiInputPort, source, nil)
			if connectStatus != noErr {
				verboseLog("Failed to connect to MIDI source \(i): \(connectStatus)")
			}
		}
	}
	
	fileprivate func processMIDIPacket(_ packet: MIDIPacket) {
		let data = withUnsafePointer(to: packet.data) { pointer in
			pointer.withMemoryRebound(to: UInt8.self, capacity: Int(packet.length)) { bytes in
				Array(UnsafeBufferPointer(start: bytes, count: Int(packet.length)))
			}
		}
		
		audioUnitManager?.processMIDIEvent(data)
	}
	
	deinit {
		// Disconnect from all sources and dispose of MIDI objects
		let sourceCount = MIDIGetNumberOfSources()
		for i in 0..<sourceCount {
			let source = MIDIGetSource(i)
			MIDIPortDisconnectSource(midiInputPort, source)
		}
		MIDIPortDispose(midiInputPort)
		MIDIClientDispose(midiClient)
	}
}

private func midiInputCallback(
	packetList: UnsafePointer<MIDIPacketList>,
	readProcRefCon: UnsafeMutableRawPointer?,
	srcConnRefCon: UnsafeMutableRawPointer?
) {
	guard let refCon = readProcRefCon else { return }
	
	let midiManager = Unmanaged<MIDIManager>.fromOpaque(refCon).takeUnretainedValue()
	let packets = packetList.pointee
	
	var packet = packets.packet
	for _ in 0..<packets.numPackets {
		midiManager.processMIDIPacket(packet)
		packet = MIDIPacketNext(&packet).pointee
	}
}

enum MIDIError: Error {
	case clientCreationFailed(status: OSStatus)
	case portCreationFailed(status: OSStatus)
}

extension MIDIError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .clientCreationFailed(let status):
			return "Failed to create MIDI client: \(status)"
		case .portCreationFailed(let status):
			return "Failed to create MIDI input port: \(status)"
		}
	}
}
