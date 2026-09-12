# Android platform repair — 1.0.29+74

Input reviewed: ElForma-changed-files.zip. Android scaffolding was missing from the preceding release. The uploaded scaffold also referenced a missing network_security_config.xml and omitted the Gradle wrapper binaries/scripts. Its Dart files contained old auth/splash logic and build 70, so they were not overlaid onto the current application.

Merged the Android configuration and retained the original raw notification audio. Applied the canonical package-import conversion to 178 directives in 43 current source files, without copying stale screen implementations. Included v2 FlutterActivity, manifest, styles, icons, notification receivers, HTTPS configuration and desugaring.

Aligned Android build tool versions with Flutter 3.38.10's official gradle_utils.dart: Gradle 8.14, AGP 8.11.1, Kotlin plugin 2.2.20. Gradle wrapper and distribution checksums were verified against the Gradle release checksums. The distribution hash is pinned in gradle-wrapper.properties. The wrapper executed Gradle 8.14 successfully on JDK 17, using a verified local copy of the same distribution for the bootstrap check.

CI now verifies the included Android platform rather than creating it as a prerequisite. Native-source files and wrapper files are not ignored. Local SDK paths and signing material are excluded from distribution.

Validation: five native-platform regression tests passed; 31 CI checks, 12 version gates, seven source checks and brand contracts passed. All manifest resource references resolve. Full Flutter dependency resolution, APK assembly and device execution were not performed for this repair.

References:
- https://raw.githubusercontent.com/flutter/flutter/3.38.10/packages/flutter_tools/lib/src/android/gradle_utils.dart
- https://github.com/gradle/gradle/tree/v8.14.0
- https://services.gradle.org/distributions/gradle-8.14-wrapper.jar.sha256
- https://services.gradle.org/distributions/gradle-8.14-bin.zip.sha256
