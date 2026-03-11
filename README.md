# @3senseai/react-native-system-speech-output

React Native bridge for system text-to-speech on iOS and Android.

## Features

- Speak plain text on iOS and Android
- iOS support for SSML on iOS 16+
- iOS support for `voiceIdentifier`
- iOS support for `preferAssistiveTechnologySettings`
- iOS support for `useSystemAudioSession`
- Android support for `pitch`
- Android support for `voiceName`
- Android support for `listVoices()`
- Android speech annotations for phones, emails, and URLs
- Speech state listener for `idle` / `speaking` / `error`

## Install from GitHub

    npm install github:abartman/react-native-system-speech-output
    cd ios && pod install && cd ..

## Install from npm

    npm install @3senseai/react-native-system-speech-output
    cd ios && pod install && cd ..

## Rebuild required

Because this package contains native iOS and Android code, rebuild the app after installing it.

## Usage

    import SpeechOutput from "@3senseai/react-native-system-speech-output";

    const available = await SpeechOutput.isAvailable();

    if (available) {
      await SpeechOutput.speak("Hello world", {
        language: "en-AU",
        rate: 0.9,
      });
    }

## API

### `isAvailable(): Promise<boolean>`

Returns whether the native speech bridge is available.

### `listVoices(): Promise<VoiceInfo[]>`

Returns available voices, mainly useful on Android for explicit voice selection.

### `speak(text, options?): Promise<boolean>`

Speaks the provided text.

Supported options:

    type SpeakOptions = {
      language?: string | null;
      rate?: number | null;
      pitch?: number | null; // Android
      voiceName?: string | null; // Android
      ssml?: string | null; // iOS
      voiceIdentifier?: string | null; // iOS
      preferAssistiveTechnologySettings?: boolean | null; // iOS
      useSystemAudioSession?: boolean | null; // iOS
    };

### `stop(): Promise<boolean>`

Stops current speech immediately.

### `addStateListener(listener)`

Subscribes to speech state updates.

## Examples

### Plain text

    await SpeechOutput.speak("Your report is ready.", {
      language: "en-AU",
      rate: 0.95,
    });

### iOS SSML

    await SpeechOutput.speak("Fallback text", {
      ssml: "<speak>Hello<break time=\"300ms\"/>world.</speak>",
    });

### iOS explicit voice selection

    await SpeechOutput.speak("Good morning", {
      voiceIdentifier: "com.apple.voice.compact.en-AU.Karen",
    });

### Android pitch and voice selection

    await SpeechOutput.speak("Good morning", {
      language: "en-AU",
      pitch: 1.05,
      voiceName: "en-au-x-aud-network",
    });

### Android voice listing

    const voices = await SpeechOutput.listVoices();
    console.log(voices);

### State listener

    const sub = SpeechOutput.addStateListener((event) => {
      console.log("speech state:", event.state);
    });

    // later
    sub.remove();

## Platform notes

### iOS

- SSML is supported on iOS 16+
- `voiceIdentifier`, `preferAssistiveTechnologySettings`, and `useSystemAudioSession` are supported
- Language matching prefers exact locale matches first, then same-base-language voices

### Android

- Plain text speech is supported
- `pitch`, `voiceName`, and `listVoices()` are supported
- Phone numbers, email addresses, and URLs are annotated for better pronunciation
- iOS-specific options are ignored safely by Android

## Notes

- If you pass both plain text and SSML on iOS 16+, SSML is preferred
- If SSML cannot be used, the module falls back to plain text
- `preferAssistiveTechnologySettings` may cause assistive settings such as VoiceOver speech preferences to take precedence over custom voice/rate values

## License

MIT
