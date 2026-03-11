import { NativeEventEmitter, Platform } from "react-native";
import NativeSystemSpeechOutput from "./src/NativeSystemSpeechOutput";

const LINKING_ERROR =
  `The package '@3senseai/react-native-system-speech-output' does not seem to be linked. Make sure the app was rebuilt after installing the package.`;

const STATE_EVENT_NAME = "SystemSpeechOutputState";
const PROGRESS_EVENT_NAME = "SystemSpeechOutputProgress";

const emitter = NativeSystemSpeechOutput
  ? new NativeEventEmitter(NativeSystemSpeechOutput)
  : null;

function getModule() {
  if (!NativeSystemSpeechOutput) {
    throw new Error(LINKING_ERROR);
  }
  return NativeSystemSpeechOutput;
}

export async function isAvailable() {
  if (!NativeSystemSpeechOutput) {
    return false;
  }
  return getModule().isAvailable();
}

export async function listVoices() {
  if (!NativeSystemSpeechOutput) {
    return [];
  }
  return getModule().listVoices();
}

export async function speak(text, options = {}) {
  return getModule().speak(text, {
    language: typeof options.language === "string" ? options.language : null,
    rate: typeof options.rate === "number" ? options.rate : null,
    pitch: typeof options.pitch === "number" ? options.pitch : null,
    voiceName: typeof options.voiceName === "string" ? options.voiceName : null,
    ssml: typeof options.ssml === "string" ? options.ssml : null,
    voiceIdentifier: typeof options.voiceIdentifier === "string" ? options.voiceIdentifier : null,
    preferAssistiveTechnologySettings:
      typeof options.preferAssistiveTechnologySettings === "boolean"
        ? options.preferAssistiveTechnologySettings
        : null,
    useSystemAudioSession:
      typeof options.useSystemAudioSession === "boolean"
        ? options.useSystemAudioSession
        : null,
  });
}

export async function stop() {
  if (!NativeSystemSpeechOutput) {
    return false;
  }
  return getModule().stop();
}

export function addStateListener(listener) {
  if (!emitter) {
    return { remove() {} };
  }
  const sub = emitter.addListener(STATE_EVENT_NAME, listener);
  return {
    remove() {
      sub.remove();
    },
  };
}

export function addProgressListener(listener) {
  if (!emitter) {
    return { remove() {} };
  }
  const sub = emitter.addListener(PROGRESS_EVENT_NAME, listener);
  return {
    remove() {
      sub.remove();
    },
  };
}

export const platformInfo = {
  platform: Platform.OS,
};

export default {
  isAvailable,
  listVoices,
  speak,
  stop,
  addStateListener,
  addProgressListener,
  platformInfo,
};
