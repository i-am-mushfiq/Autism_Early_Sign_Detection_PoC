# Sanket release signing

The first public release uses `sanket-release.jks` with alias `sanket-release`.
Passwords and the relative keystore path are in `android/key.properties`.
Both credential files are excluded from Git. They are outside `build/`, so
`flutter clean` does not delete them.

Keep a private backup of **both** `android/signing/sanket-release.jks` and
`android/key.properties`. Future releases of `com.sanket.sanket_mobile`
must use this same signing key. Do not upload either credential file to APKPure;
upload only the APK in `release-artifacts/`.

Build from the app directory:

```powershell
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

Increment `version` in `pubspec.yaml` for later public updates.
The locally tested older APKs used a debug certificate. The public release
cannot update those debug-signed installations directly. No installed app or
saved phone data was removed while preparing this release.
