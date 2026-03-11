#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_NAME="$(python3 - <<'PY'
import json
from pathlib import Path
pkg = json.loads(Path("package.json").read_text(encoding="utf-8"))
print(pkg["name"])
PY
)"
TARGET_DIR="${1:-$PACKAGE_DIR/../speech-output-example-app}"
APP_NAME="$(basename "$TARGET_DIR")"
PARENT_DIR="$(dirname "$TARGET_DIR")"

if [ -e "$TARGET_DIR" ]; then
  echo "Target already exists: $TARGET_DIR"
  echo "Delete it or pass a different path."
  exit 1
fi

mkdir -p "$PARENT_DIR"
cd "$PARENT_DIR"

npx @react-native-community/cli@latest init "$APP_NAME" --version 0.84.0

cd "$TARGET_DIR"
npm install "$PACKAGE_DIR"

python3 - <<PY
from pathlib import Path
package_name = ${PACKAGE_NAME@Q}
app = Path("App.tsx")
app.write_text(f'''import React, {{useEffect, useState}} from "react";
import {{SafeAreaView, ScrollView, Text, Button}} from "react-native";
import SpeechOutput from "{package_name}";

export default function App() {{
  const [available, setAvailable] = useState<boolean | null>(null);
  const [voices, setVoices] = useState<any[]>([]);

  useEffect(() => {{
    (async () => {{
      const ok = await SpeechOutput.isAvailable();
      setAvailable(ok);
      const v = await SpeechOutput.listVoices();
      setVoices(v);
    }})();
  }}, []);

  return (
    <SafeAreaView style={{{{flex: 1, padding: 24}}}}>
      <ScrollView contentContainerStyle={{{{gap: 12}}}}>
        <Text style={{{{fontSize: 22, fontWeight: "600"}}}}>
          Speech Output Example
        </Text>
        <Text>available: {{{{String(available)}}}}</Text>
        <Text>voices: {{{{voices.length}}}}</Text>
        <Button
          title="Speak sample"
          onPress={{async () => {{
            await SpeechOutput.speak("Hello from the example app.", {{
              language: "en-AU",
              rate: 0.95,
              pitch: 1.0,
            }});
          }}}}
        />
      </ScrollView>
    </SafeAreaView>
  );
}}
''', encoding="utf-8")
PY

if ! grep -q '^newArchEnabled=' android/gradle.properties; then
  printf '\nnewArchEnabled=true\n' >> android/gradle.properties
else
  python3 - <<'PY'
from pathlib import Path
p = Path("android/gradle.properties")
txt = p.read_text(encoding="utf-8")
txt = txt.replace("newArchEnabled=false", "newArchEnabled=true")
p.write_text(txt, encoding="utf-8")
PY
fi

cat <<MSG

Example app created at:
  $TARGET_DIR

Next commands:

  cd "$TARGET_DIR"
  cd ios && RCT_NEW_ARCH_ENABLED=1 pod install && cd ..
  npx react-native run-ios

And in another terminal if you want Android:
  cd "$TARGET_DIR"
  npx react-native run-android
MSG
