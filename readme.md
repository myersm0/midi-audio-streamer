# midi-audio-streamer

## Introduction
A Swift application that loads and runs MIDI software instruments on macOS. Exposes the real-time audio buffer stream over TCP, allowing an external application (not included) to capture and handle the raw audio data.

## Requirements
- macOS 13.0+
- Swift 5.9+
- a software instrument
- a MIDI keyboard or controller

## Setup and installation
To build, clone this repo, cd into the directory, and run `swift build -c release`. The executable will be created at `.build/release/AudioUnitHost`.

Then to run it you will need to find the 4-character subtype and manufacturer codes for your software instrument:
1. List all available instruments: `auval -a | grep aumu`
2. The format is: `aumu SUBTYPE MANUFACTURER`
   - `aumu` means it's a software instrument
   - `SUBTYPE` is exactly 4 characters (pad with spaces if needed)
   - `MANUFACTURER` is exactly 4 characters
3. For example: `aumu    dls     appl     AudioUnit: Apple: DLSMusicDevice` means: `--subtype "dls " --manufacturer "appl"`

## Usage
```bash
# Basic usage with Pianoteq
./AudioUnitHost --subtype "Pt8q" --manufacturer "Mdrt"

# With verbose output
./AudioUnitHost --subtype "Pt8q" --manufacturer "Mdrt" --verbose

```

## Command line options
- `-s, --subtype`: Software instrument identifier (required)
- `-m, --manufacturer`: Software instrument manufacturer code (required)  
- `-v, --verbose`: Enable verbose logging
- `-p, --port`: TCP port for streaming (default: 9999)
- `-h, --host`: TCP host for streaming (default: 127.0.0.1)
- `--help`: Show help message

