# Security policy

Please report vulnerabilities privately through GitHub's security advisory
interface for `iebb/f-videoplayer`. Do not include content keys, DRM license
messages, tokens, signed media URLs, user identifiers, or production media in
an issue or test fixture.

The current release does not implement DRM. A future DRM backend must keep
license challenges, responses, certificates, and authentication material out
of logs and crash reports.
