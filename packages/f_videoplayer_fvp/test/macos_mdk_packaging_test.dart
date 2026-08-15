import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native packaging pins MDK 0.38.0 with release digests', () {
    final manifest = File(
      '../../third_party/fvp/darwin/fvp/Package.swift',
    ).readAsStringSync();
    final cmake = File(
      '../../third_party/fvp/cmake/deps.cmake',
    ).readAsStringSync();

    expect(manifest, contains('releases/download/v0.38.0/mdk-sdk-apple.zip'));
    expect(
      manifest,
      contains(
        'dfae61b90ae1cc543d173b3b4cf2411856c98d61a3a56d7b032573080b8d18a5',
      ),
    );
    expect(cmake, contains('releases/download/v0.38.0'));
    for (final digest in [
      'bec03fac5baee70df316981c5a63fe8be0efa80911c97f14840d2deef82928ce',
      '57d38877a72607c5d135699207320d757b8c6b60437e8fb9b984ede5265a9c06',
      'ac9ee8a4d24bb8a3d8294ff60fada7244145b8469fc1abbff8a9d45458b4de6a',
      '6491cefb136ca56401c27947b5ee37e6533965f1aff826f1a6880a961c554672',
      '0ce5cc02a2adb07bd0d043d2cb88bbd97669282f848624ea3dd10d537757aff7',
      '9ce29b1c29aa2d051e52f50af8a1578ab80f6d17955a2935514e1c69b8a23d3e',
    ]) {
      expect(cmake, contains(digest));
    }
  });

  test('Apple SPM delegates Flutter linkage to FlutterFramework product', () {
    final manifest = File(
      '../../third_party/fvp/darwin/fvp/Package.swift',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        '.package(name: "FlutterFramework", path: "../FlutterFramework")',
      ),
    );
    expect(
      manifest,
      contains(
        '.product(name: "FlutterFramework", package: "FlutterFramework")',
      ),
    );
    expect(
      manifest,
      contains('.library(name: "fvp", type: .static, targets: ["fvp"])'),
    );
    expect(manifest, isNot(contains('type: .dynamic')));
    expect(manifest, isNot(contains('.linkedFramework("Flutter"')));
    expect(manifest, isNot(contains('.linkedFramework("FlutterMacOS"')));

    // Native Apple SDK frameworks remain explicit because the generated
    // FlutterFramework product supplies only Flutter's engine framework.
    expect(
      manifest,
      contains('.linkedFramework("UIKit", .when(platforms: [.iOS]))'),
    );
    for (final framework in [
      'AVFoundation',
      'AVKit',
      'CoreMedia',
      'CoreVideo',
      'Metal',
    ]) {
      expect(manifest, contains('.linkedFramework("$framework")'));
    }
  });

  test('macOS hosts sanitize embedded MDK before final app signing', () {
    final script = File(
      '../../third_party/fvp/darwin/fvp/tool/sanitize_mdk_macos.sh',
    ).readAsStringSync();
    final exampleProject = File(
      '../f_videoplayer/example/macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(script, contains('set -euo pipefail'));
    expect(script, contains(r'mdk_binary="$mdk_framework/Versions/A/mdk"'));
    expect(script, contains('install_name_tool'));
    expect(script, contains('-delete_rpath'));
    expect(script, contains('/opt/homebrew/lib'));
    expect(script, contains('/usr/local/lib'));
    expect(script, isNot(contains('grep -Fq')));
    expect(script, contains(r'load_commands="$(/usr/bin/otool -l'));
    expect(script, contains('EXPANDED_CODE_SIGN_IDENTITY'));
    expect(script, contains("-type f -name '*.dylib' -print0"));
    expect(script, contains(r'codesign --verify --strict "$nested_dylib"'));
    expect(script, contains('codesign --verify --deep --strict'));
    expect(
      script.indexOf(r'--sign "$signing_identity"'),
      lessThan(script.lastIndexOf(r'--sign "$signing_identity"')),
    );
    expect(
      script.indexOf(r'"$nested_dylib"'),
      lessThan(script.indexOf(r'"$mdk_framework"')),
    );

    expect(exampleProject, contains('Sanitize embedded MDK'));
    expect(exampleProject, contains('/bin/bash'));
    expect(
      exampleProject,
      contains(
        r'$SRCROOT/Flutter/ephemeral/Packages/.packages/fvp/tool/'
        'sanitize_mdk_macos.sh',
      ),
    );
    expect(
      exampleProject.indexOf('3399D490228B24CF009A79C7 /* ShellScript */,'),
      lessThan(exampleProject.indexOf('Sanitize embedded MDK */,')),
    );
  });
}
