import AVFoundation
import AudioToolbox
import Foundation

class AudioUnitManager {
	let audioUnit: AudioComponentInstance
	let outputUnit: AudioComponentInstance?
	let outputFormat: AudioStreamBasicDescription
	private var sampleTime: Float64 = 0
	private let renderLock = NSLock()
	
	init(config: Config) throws {
		verboseLog("Searching for audio unit with subtype: \(config.componentSubType), manufacturer: \(config.componentManufacturer)")
		
		// Find the audio unit
		var componentDescription = AudioComponentDescription(
			componentType: kAudioUnitType_MusicDevice,
			componentSubType: Self.makeFourCC(config.componentSubType),
			componentManufacturer: Self.makeFourCC(config.componentManufacturer),
			componentFlags: 0,
			componentFlagsMask: 0
		)
		
		guard let component = AudioComponentFindNext(nil, &componentDescription) else {
			throw AudioUnitError.componentNotFound(subtype: config.componentSubType, manufacturer: config.componentManufacturer)
		}
		
		verboseLog("Found audio unit component")
		
		// Create audio unit instance
		var audioUnit: AudioComponentInstance?
		let status = AudioComponentInstanceNew(component, &audioUnit)
		guard status == noErr, let au = audioUnit else {
			throw AudioUnitError.instantiationFailed(status: status)
		}
		
		self.audioUnit = au
		verboseLog("Audio unit instantiated successfully")
		
		// Get preferred format
		var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
		var outputFormat = AudioStreamBasicDescription()
		AudioUnitGetProperty(
			au,
			kAudioUnitProperty_StreamFormat,
			kAudioUnitScope_Output,
			0,
			&outputFormat,
			&size
		)
		
		self.outputFormat = outputFormat
		
		print("Audio Unit's preferred format:")
		print("  Sample Rate: \(outputFormat.mSampleRate)")
		print("  Channels: \(outputFormat.mChannelsPerFrame)")
		print("  Bits per channel: \(outputFormat.mBitsPerChannel)")
		print("  Format flags: \(outputFormat.mFormatFlags)")
		
		// Set maximum frames per slice
		var maxFrames: UInt32 = 4096
		AudioUnitSetProperty(
			au,
			kAudioUnitProperty_MaximumFramesPerSlice,
			kAudioUnitScope_Global,
			0,
			&maxFrames,
			UInt32(MemoryLayout<UInt32>.size)
		)
		
		verboseLog("Set maximum frames per slice to \(maxFrames)")
		
		// Initialize the audio unit
		let initStatus = AudioUnitInitialize(au)
		if initStatus != noErr {
			throw AudioUnitError.initializationFailed(status: initStatus)
		}
		
		print("Audio Unit initialized successfully")
		
		// Set up output unit
		self.outputUnit = try Self.createOutputUnit(format: outputFormat)
		
		// Give audio unit time to fully initialize
		Thread.sleep(forTimeInterval: 0.5)
		verboseLog("Audio Unit initialization complete")
	}
	
	private static func createOutputUnit(format: AudioStreamBasicDescription) throws -> AudioComponentInstance? {
		var outputDescription = AudioComponentDescription(
			componentType: kAudioUnitType_Output,
			componentSubType: kAudioUnitSubType_DefaultOutput,
			componentManufacturer: kAudioUnitManufacturer_Apple,
			componentFlags: 0,
			componentFlagsMask: 0
		)
		
		guard let outputComponent = AudioComponentFindNext(nil, &outputDescription) else {
			print("Warning: Could not find output audio unit")
			return nil
		}
		
		verboseLog("Found output audio unit")
		
		var outputUnit: AudioComponentInstance?
		let outputStatus = AudioComponentInstanceNew(outputComponent, &outputUnit)
		
		guard outputStatus == noErr, let output = outputUnit else {
			print("Warning: Failed to create output audio unit")
			return nil
		}
		
		verboseLog("Output audio unit instantiated")
		
		// Configure output with same format as main audio unit
		var outputFormat = format
		AudioUnitSetProperty(
			output,
			kAudioUnitProperty_StreamFormat,
			kAudioUnitScope_Input,
			0,
			&outputFormat,
			UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
		)
		
		// Initialize and start output
		guard AudioUnitInitialize(output) == noErr else {
			print("Warning: Failed to initialize audio output")
			return nil
		}
		
		AudioOutputUnitStart(output)
		print("Audio output initialized - you should hear sound now!")
		
		return output
	}
	
	func processMIDIEvent(_ data: [UInt8]) {
		renderLock.lock()
		defer { renderLock.unlock() }
		
		if data.count == 3 {
			MusicDeviceMIDIEvent(
				audioUnit,
				UInt32(data[0]),
				UInt32(data[1]),
				UInt32(data[2]),
				0
			)
			
			let status = data[0] & 0xF0
			let channel = data[0] & 0x0F
			
			if status == 0x90 && data[2] > 0 {
				verboseLog("Note On - Channel: \(channel), Note: \(data[1]), Velocity: \(data[2])")
			} else if status == 0x80 || (status == 0x90 && data[2] == 0) {
				verboseLog("Note Off - Channel: \(channel), Note: \(data[1])")
			}
		}
	}
	
	func renderAudio(frames: UInt32) -> Data? {
		renderLock.lock()
		defer { renderLock.unlock() }
		
		var inTimeStamp = AudioTimeStamp()
		memset(&inTimeStamp, 0, MemoryLayout<AudioTimeStamp>.size)
		inTimeStamp.mSampleTime = sampleTime
		inTimeStamp.mFlags = .sampleTimeValid
		
		// Use AudioBufferList.allocate for safety
		let audioBufferList = AudioBufferList.allocate(maximumBuffers: 2)
		defer { audioBufferList.unsafeMutablePointer.deallocate() }
		
		for i in 0..<2 {
			audioBufferList[i] = AudioBuffer(
				mNumberChannels: 1,
				mDataByteSize: frames * 4,
				mData: malloc(Int(frames * 4))
			)
			// Clear the buffer
			memset(audioBufferList[i].mData, 0, Int(frames * 4))
		}
		
		defer {
			for i in 0..<2 {
				free(audioBufferList[i].mData)
			}
		}
		
		var ioActionFlags = AudioUnitRenderActionFlags()
		let renderStatus = AudioUnitRender(
			audioUnit,
			&ioActionFlags,
			&inTimeStamp,
			0,
			frames,
			audioBufferList.unsafeMutablePointer
		)
		
		if renderStatus == noErr {
			sampleTime += Float64(frames)
			
			// Play audio through speakers if we have an output unit
			if let output = outputUnit {
				var outputFlags = AudioUnitRenderActionFlags()
				AudioUnitRender(
					output,
					&outputFlags,
					&inTimeStamp,
					0,
					frames,
					audioBufferList.unsafeMutablePointer
				)
			}
			
			// Get left channel data for network transmission
			if let audioData = audioBufferList[0].mData {
				let floatPointer = audioData.assumingMemoryBound(to: Float.self)
				
				// Check for audio
				var maxSample: Float = 0
				for i in 0..<Int(frames) {
					let sample = abs(floatPointer[i])
					if sample > maxSample && sample < 10.0 {  // Sanity check
						maxSample = sample
					}
				}
				
				if maxSample > 0.0001 {
					verboseLog("Audio level: \(maxSample)")
				}
				
				return Data(bytes: audioData, count: Int(frames * 4))
			}
		} else if renderStatus != -10878 {  // -10878 is kAudioUnitErr_InvalidParameter
			verboseLog("Render error: \(renderStatus)")
		}
		
		return nil
	}
	
	private static func makeFourCC(_ string: String) -> OSType {
		var result: OSType = 0
		for byte in string.utf8 {
			result = (result << 8) + OSType(byte)
		}
		return result
	}
	
	deinit {
		AudioUnitUninitialize(audioUnit)
		if let output = outputUnit {
			AudioOutputUnitStop(output)
			AudioUnitUninitialize(output)
		}
	}
}

enum AudioUnitError: Error {
	case componentNotFound(subtype: String, manufacturer: String)
	case instantiationFailed(status: OSStatus)
	case initializationFailed(status: OSStatus)
}

extension AudioUnitError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .componentNotFound(let subtype, let manufacturer):
			return "Audio Unit not found with subtype '\(subtype)' and manufacturer '\(manufacturer)'"
		case .instantiationFailed(let status):
			return "Failed to instantiate Audio Unit: \(status)"
		case .initializationFailed(let status):
			return "AudioUnit initialization failed: \(status)"
		}
	}
}
