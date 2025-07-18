import Foundation

struct Config {
	let componentSubType: String
	let componentManufacturer: String
	let verbose: Bool
	let port: Int
	let host: String
	
	static func parse() -> Config {
		let args = CommandLine.arguments
		
		var componentSubType = ""
		var componentManufacturer = ""
		var verbose = false
		var port = 9999
		var host = "127.0.0.1"
		
		var i = 1
		while i < args.count {
			switch args[i] {
			case "-s", "--subtype":
				guard i + 1 < args.count else {
					fatalError("Missing value for --subtype")
				}
				componentSubType = args[i + 1]
				i += 2
			case "-m", "--manufacturer":
				guard i + 1 < args.count else {
					fatalError("Missing value for --manufacturer")
				}
				componentManufacturer = args[i + 1]
				i += 2
			case "-v", "--verbose":
				verbose = true
				i += 1
			case "-p", "--port":
				guard i + 1 < args.count else {
					fatalError("Missing value for --port")
				}
				port = Int(args[i + 1]) ?? 9999
				i += 2
			case "-h", "--host":
				guard i + 1 < args.count else {
					fatalError("Missing value for --host")
				}
				host = args[i + 1]
				i += 2
			case "--help":
				printUsage()
				exit(0)
			default:
				print("Unknown argument: \(args[i])")
				printUsage()
				exit(1)
			}
		}
		
		if componentSubType.isEmpty || componentManufacturer.isEmpty {
			print("Error: Both --subtype and --manufacturer are required")
			printUsage()
			exit(1)
		}
		
		return Config(
			componentSubType: componentSubType,
			componentManufacturer: componentManufacturer,
			verbose: verbose,
			port: port,
			host: host
		)
	}
	
	private static func printUsage() {
		print("""
		Usage: AudioUnitHost [OPTIONS]
		
		Required:
		  -s, --subtype SUBTYPE           Audio unit subtype (e.g., "Pt8q")
		  -m, --manufacturer MANUFACTURER Audio unit manufacturer (e.g., "Mdrt")
		
		Optional:
		  -v, --verbose                   Enable verbose output
		  -p, --port PORT                 TCP port (default: 9999)
		  -h, --host HOST                 TCP host (default: 127.0.0.1)
		  --help                          Show this help message
		
		Example:
		  AudioUnitHost --subtype "Pt8q" --manufacturer "Mdrt" --verbose
		""")
	}
}

// Global config instance
var globalConfig: Config!

func verboseLog(_ message: String) {
	if globalConfig.verbose {
		print("[VERBOSE] \(message)")
	}
}
