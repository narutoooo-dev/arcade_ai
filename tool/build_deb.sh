#!/bin/bash
# Packages the Linux release bundle into a .deb.
# Usage: tool/build_deb.sh   (run after: flutter build linux --release)
set -euo pipefail
cd "$(dirname "$0")/.."

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
BUNDLE=build/linux/x64/release/bundle
[ -d "$BUNDLE" ] || { echo "bundle not found — run: flutter build linux --release" >&2; exit 1; }

STAGE=build/deb/arcade-ai_${VER}_amd64
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/lib/arcade-ai" "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" "$STAGE/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE"/. "$STAGE/usr/lib/arcade-ai/"
ln -s ../lib/arcade-ai/arcade_ai "$STAGE/usr/bin/arcade-ai"
cp assets/icons/icon.png "$STAGE/usr/share/icons/hicolor/512x512/apps/arcade-ai.png"

cat > "$STAGE/usr/share/applications/arcade-ai.desktop" <<EOF
[Desktop Entry]
Name=Arcade AI
Comment=Universal multi-provider LLM chat client
Exec=/usr/bin/arcade-ai
Icon=arcade-ai
Terminal=false
Type=Application
Categories=Utility;Network;Chat;
EOF

SIZE=$(du -sk "$STAGE/usr" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: arcade-ai
Version: $VER
Section: net
Priority: optional
Architecture: amd64
Installed-Size: $SIZE
Depends: libgtk-3-0, libsecret-1-0
Maintainer: NickIBrody <nickibrody@users.noreply.github.com>
Homepage: https://github.com/NickIBrody/arcade_ai
Description: Universal multi-provider LLM chat client
 Chat with any large language model: OpenAI, Anthropic, Google,
 GigaChat, Ollama and more. Bring your own API key.
EOF

dpkg-deb --build --root-owner-group "$STAGE" "build/ArcadeAI-${VER}-amd64.deb"
echo "-> build/ArcadeAI-${VER}-amd64.deb"
