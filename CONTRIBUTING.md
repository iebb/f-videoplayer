# Contributing

Keep backend-specific playback and native presentation in optional packages;
the core player must remain usable with Flutter's official `video_player`
implementations.

Before opening a change, run analyze and tests for every affected package and
compile the example on each affected platform. New controls need keyboard,
pointer/touch, RTL, large-text, and screen-reader coverage. Keep interactive
targets at least 44 logical pixels and preserve a volume action in compact
layouts whenever it physically fits.

Do not commit downloaded MDK binaries, DRM SDKs, CDMs, credentials, signed
media URLs, or license-server payloads.
