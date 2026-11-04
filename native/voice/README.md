# Fixed client codec dependency

Godotopus **v0.0.2, no DNN** from Mako Mako Games, https://github.com/Mako-Mako-Games/godotopus/releases/tag/v0.0.2 . The release ZIP SHA-256 is `069d54a3d128fcf3b2d4b647545866cbdc298f14ea846b6eb87799c22b4cb7db`. Only the two Windows x86-64 client DLLs are shipped here. MIT addon, BSD Opus/SpeexDSP and MIT godot-cpp notices are preserved in `licenses/`.

Pinned source submodules: Opus `3da9f7a6db1c05c3996cb363a9d1931a978bf1be`, SpeexDSP `7a158783df74efe7c2d1c6ee8363c1e695c71226`, godot-cpp `1d713bdbe843ebd390b48bdc61aaa437e42f4f73`.

Uses the codec/resampler classes only. No addon transport or microphone scripts are loaded. No DRED or neural audio processing is enabled. The server relays compressed bytes and must exclude this directory from its dedicated export. Runtime GDScript creates native classes dynamically, allowing servers without this dependency to parse/run the voice relay.

The client uses Godot 4.7 `AudioServer.set_input_device_active`, `get_input_mix_rate`, `get_input_frames_available` and `get_input_frames`. Capture is activated only while push-to-talk is held and stopped/drained on release. It never creates an AudioStreamMicrophone monitor or writes audio to a recording file.

## Windows distribution

Godot exports the release codec as `libgodotopus.windows.template_release.x86_64.dll` **beside the game executable**. The native library cannot be loaded directly from the encrypted PCK. `distribution/publish.py` requires and signs exactly the game EXE, PCK and this release DLL; the debug DLL is never part of a release. The `.gdextension` remapping and license notices stay in the PCK. Linux headless exports exclude this directory and relay voice without a codec.

The updated launcher accepts the previous two-file packages and these exact three-file packages. Each file, including the DLL, has its size and SHA-256 verified before installation and launch. Other libraries, nested paths, duplicate ZIP entries and traversal names are rejected.

Existing installed launchers only understand two-file packages and do not update themselves. Before releasing the first native-voice client, rebuild/distribute the updated launcher and tell current players to download/replace the launcher once. A new game manifest alone cannot migrate an old launcher. Do not publish until the complete exported game and launcher are approved and validated together.

`python distribution/validate_native_package.py` exercises the actual launcher verifier/extractor in a disposable QA project with a fresh signing key and dummy EXE/PCK/DLL payloads. It checks old/new packages, per-DLL corruption and truncation, missing/extra files, debug DLLs, duplicate entries and path traversal. It neither exports a game nor reads production private keys, changes an installation or publishes anything. The separate exported-launcher/update integration test remains necessary after the approved build.
