import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export type VoiceInfo = {
  name: string;
  locale?: string;
  quality?: number;
  latency?: number;
  networkRequired?: boolean;
  features?: string[];
};

export interface Spec extends TurboModule {
  addListener(eventName: string): void;
  removeListeners(count: number): void;
  isAvailable(): Promise<boolean>;
  listVoices(): Promise<VoiceInfo[]>;
  speak(text: string, options: Object | null): Promise<boolean>;
  stop(): Promise<boolean>;
}

export default TurboModuleRegistry.get<Spec>('SystemSpeechOutput');
