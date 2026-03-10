# react-native-system-speech-output

React Native bridge for system text-to-speech on iOS and Android.

## Install from GitHub

```bash
npm install github:abartman/react-native-system-speech-output
cd ios && pod install && cd ..
```

## Usage

```ts
import SpeechOutput from "react-native-system-speech-output";

const available = await SpeechOutput.isAvailable();

if (available) {
  await SpeechOutput.speak("Hello world", {
    language: "en-AU",
    rate: 0.9
  });
}
```

## API

- `isAvailable(): Promise<boolean>`
- `speak(text, options?): Promise<boolean>`
- `stop(): Promise<boolean>`
- `addStateListener(listener)`
