export type SpeechOutputState = "idle" | "speaking" | "error" | "unavailable";

export type SpeechProgressEvent = {
  utteranceId: string;
  start: number;
  end: number;
};

export type SpeakOptions = {
  language?: string | null;
  rate?: number | null;
  pitch?: number | null;
  voiceName?: string | null;
  ssml?: string | null;
  voiceIdentifier?: string | null;
  preferAssistiveTechnologySettings?: boolean | null;
  useSystemAudioSession?: boolean | null;
};

export type VoiceInfo = {
  name: string;
  locale?: string | null;
  quality?: number;
  latency?: number;
  networkRequired?: boolean;
  features?: string[];
};

export function isAvailable(): Promise<boolean>;
export function listVoices(): Promise<VoiceInfo[]>;
export function speak(text: string, options?: SpeakOptions): Promise<boolean>;
export function stop(): Promise<boolean>;
export function addStateListener(
  listener: (event: { state?: SpeechOutputState }) => void,
): { remove(): void };
export function addProgressListener(
  listener: (event: SpeechProgressEvent) => void,
): { remove(): void };

declare const _default: {
  isAvailable: typeof isAvailable;
  listVoices: typeof listVoices;
  speak: typeof speak;
  stop: typeof stop;
  addStateListener: typeof addStateListener;
  addProgressListener: typeof addProgressListener;
  platformInfo: { platform: string };
};

export default _default;
