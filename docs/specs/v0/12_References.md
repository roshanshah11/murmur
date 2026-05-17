# References Used for Current Assumptions

These are not implementation links required by the app; they are current references used to shape the PRD and technical choices.

## whisper.cpp

- Source: `ggml-org/whisper.cpp` repository.
- Relevant assumption: `whisper.cpp` can run Whisper locally and supports Apple Silicon acceleration paths including Metal/Core ML usage.
- URL: https://github.com/ggml-org/whisper.cpp

## Apple AVFoundation

- Source: Apple Developer Documentation, AVFoundation audio playback/recording/processing.
- Relevant assumption: AVFoundation is the native Apple framework for audio recording/capture and processing.
- URL: https://developer.apple.com/documentation/avfoundation/audio-playback-recording-and-processing

## Apple Accessibility / AXUIElement

- Source: Apple Developer Documentation, AXUIElement and Accessibility APIs.
- Relevant assumption: macOS accessibility objects expose UI metadata and can support future focused-element/context functionality.
- URL: https://developer.apple.com/documentation/applicationservices/axuielement

## Tauri v2 global shortcut and clipboard docs

- Source: Tauri v2 documentation.
- Relevant assumption: if a later cross-platform build is desired, Tauri has plugin paths for global shortcuts and clipboard access, but permissions must be explicitly configured.
- URLs:
  - https://v2.tauri.app/plugin/global-shortcut/
  - https://v2.tauri.app/plugin/clipboard/
  - https://v2.tauri.app/security/permissions/

## Design note

The implementation in this bundle does not depend on Tauri. Tauri is mentioned only as a later cross-platform option. The starter implementation uses Swift/AppKit/AVFoundation plus a local `whisper.cpp` CLI sidecar.
