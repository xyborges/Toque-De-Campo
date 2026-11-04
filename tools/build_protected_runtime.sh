#!/bin/sh
set -eu
cd /home/microgate/toque-build
umask 077
if [ ! -d godot-4.7.2-stable ]; then
    curl --fail --location --proto '=https' --tlsv1.2 https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/4.7.2-stable --output godot-4.7.2.tar.gz
    tar -xzf godot-4.7.2.tar.gz
fi
while ! command -v scons >/dev/null 2>&1 || ! command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1; do sleep 5; done
cd godot-4.7.2-stable
python3 - <<'PY'
from pathlib import Path
p=Path('core/config/project_settings.cpp')
s=p.read_text()
marker='// TDC: shipped templates do not load external project overrides.'
if marker not in s:
    anchor='#include "project_settings.h"'
    assert anchor in s
    s=s.replace(anchor,marker+'\n#ifndef TOOLS_ENABLED\n#undef OVERRIDE_ENABLED\n#endif\n'+anchor,1)
    p.write_text(s)
PY
# The key stays in this private build directory and the resulting runtime.
export SCRIPT_AES256_ENCRYPTION_KEY="$(cat ../pck-key.hex)"
scons platform=windows target=template_release arch=x86_64 use_mingw=yes vulkan=yes d3d12=no debug_symbols=no lto=none -j6
unset SCRIPT_AES256_ENCRYPTION_KEY
sha256sum bin/godot.windows.template_release.x86_64.exe > ../runtime.sha256
printf '\nPROTECTED_RUNTIME_BUILD_COMPLETE\n'
