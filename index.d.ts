export type SpeechOutputState = "idle" | "speaking" | "error" | "unavailable";

export type SpeakOptions = {
  language?: string | null;
  rate?: number | null;
};

export function isAvailable(): Promise<boolean>;
export function speak(text: string, options?: SpeakOptions): Promise<boolean>;
export function stop(): Promise<boolean>;
export function addStateListener(
  listener: (event: { state?: SpeechOutputState }) => void,
): { remove(): void };

declare const _default: {
  isAvailable: typeof isAvailable;
  speak: typeof speak;
  stop: typeof stop;
  addStateListener: typeof addStateListener;
  platformInfo: { platform: string };
};

export default _default;
