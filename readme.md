# midi-audio-streamer

## Introduction
A Swift application that loads and runs MIDI software instruments on macOS. Exposes the real-time audio buffer stream over TCP, allowing an external application (not included) to capture and handle the raw audio data. 

Optionally, if your VST is by Modartt (i.e. Pianoteq or Organteq), you can monitor a JSON-RPC server to track your instrument's parameter changes in real-time.

## Requirements
- macOS 13.0+
- Swift 5.9+
- A software instrument (like Pianoteq, Organteq, or Apple's built-in synthesizers)
- A MIDI keyboard or controller

## Setup and installation

### Building
```bash
git clone https://github.com/myersm0/midi-audio-streamer
cd midi-audio-streamer
swift build -c release
```
The executable will be created at `.build/release/AudioUnitHost`.

### Finding your instrument codes
To run the application, you need to find the 4-character subtype and manufacturer codes for your software instrument:

1. List all available instruments:
   ```bash
   auval -a | grep aumu
   ```

2. The format is: `aumu SUBTYPE MANUFACTURER`
   - `aumu` means it's a software instrument
   - `SUBTYPE` is exactly 4 characters (pad with spaces if needed)
   - `MANUFACTURER` is exactly 4 characters

3. Examples:
   - Apple DLS Synth: `aumu    dls     appl` → `--subtype "dls " --manufacturer "appl"`
   - Pianoteq 9: `--subtype "Pt9q" --manufacturer "Mdrt"`
   - Organteq 2: `--subtype "Orgq" --manufacturer "Mdrt"`

## Usage

### Basic usage
```bash
# With Apple's built-in DLS synth
./AudioUnitHost --subtype "dls " --manufacturer "appl"

# With Pianoteq 9
./AudioUnitHost --subtype "Pt9q" --manufacturer "Mdrt"

# With verbose output
./AudioUnitHost --subtype "Pt9q" --manufacturer "Mdrt" --verbose
```

### With JSON-RPC monitoring
To monitor parameter changes from Pianoteq or Organteq's GUI:

1. Start Pianoteq with JSON-RPC server:
   ```bash
    /Applications/Pianoteq\ 9/Pianoteq\ 9.app/Contents/MacOS/Pianoteq\ 9 --serve ""
   ```

2. In another terminal, run the audio streamer with RPC enabled:
   ```bash
   ./build/release/AudioUnitHost --subtype "Pt9q" --manufacturer "Mdrt" --enable-rpc
   ```

3. Changes you make in the Pianoteq GUI will be logged to stdout:
   ```
   [RPC] Parameter changed: Output Volume = -6.0 dB (id: output_volume)
   [RPC] Preset changed to: NY Steinway D
   [RPC] Preset reset to saved state
   ```

### Advanced usage
```bash
# Custom TCP host and port for audio streaming
./AudioUnitHost -s "Pt9q" -m "Mdrt" -h "192.168.1.100" -p 8888

# Custom buffer size and RPC polling interval
./AudioUnitHost -s "Pt9q" -m "Mdrt" --enable-rpc \
  --buffer-size 1024 \
  --rpc-poll-interval 0.3

# Connect to RPC server on different host/port
./AudioUnitHost -s "Pt9q" -m "Mdrt" --enable-rpc \
  --rpc-host "127.0.0.1" \
  --rpc-port 8082
```

## Command line options

### Required
- `-s, --subtype SUBTYPE` - Software instrument identifier (e.g., "Pt9q")
- `-m, --manufacturer MANUFACTURER` - Software instrument manufacturer code (e.g., "Mdrt")

### Optional - audio streaming
- `-v, --verbose` - Enable verbose logging
- `-p, --port PORT` - TCP port for audio streaming (default: 9999)
- `-h, --host HOST` - TCP host for audio streaming (default: 127.0.0.1)
- `--buffer-size SIZE` - Audio buffer size in frames (default: 512)

### Optional - JSON-RPC monitoring
- `--enable-rpc` - Enable JSON-RPC parameter monitoring
- `--rpc-host HOST` - JSON-RPC server host (default: 127.0.0.1)
- `--rpc-port PORT` - JSON-RPC server port (default: 8081)
- `--rpc-poll-interval SECONDS` - How often to check for parameter changes (default: 0.5)

## Project Structure

```
midi-audio-streamer/
├── Package.swift
├── Sources/
│   ├── main.swift              # Main entry point and audio loop
│   ├── Config.swift            # Command line argument parsing
│   ├── AudioUnitManager.swift  # Software instrument loading and audio rendering
│   ├── MIDIManager.swift       # MIDI keyboard input handling
│   ├── NetworkManager.swift    # TCP network audio streaming
│   └── ModarttRPC.swift        # JSON-RPC client for Pianoteq/Organteq
└── README.md
```

