// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "AudioUnitHost",
	platforms: [
		.macOS(.v13)
	],
	products: [
		.executable(
			name: "AudioUnitHost",
			targets: ["AudioUnitHost"]
		)
	],
	targets: [
		.executableTarget(
			name: "AudioUnitHost",
			dependencies: [],
			path: "Sources"
		)
	]
)
