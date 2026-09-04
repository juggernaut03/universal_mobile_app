# shreemegamart flavor — Firebase config needed

This flavor's `applicationId` is `com.shreemegamart.androidapp`. Before it
can build, add a `google-services.json` here (this directory) for an Android
app registered under that package name in the Firebase project used for push
notifications.

Without it, `./gradlew assembleShreemegamartDebug` (and the matching
`flutter build ... --flavor shreemegamart`) fails at the
`com.google.gms.google-services` step with "No matching client found for
package name 'com.shreemegamart.androidapp'".

Also needed before a signed release build: `android/key.shreemegamart.properties`
pointing at a keystore (see `android/key.myneedmart.properties` for the
expected shape). Until then, release builds for this flavor fall back to the
debug signing key.

Optional: drop `mipmap-*/launcher_icon.png` overrides in
`android/app/src/shreemegamart/res/` for a tenant-specific app icon;
otherwise the shared icon in `src/main/res` is used.
