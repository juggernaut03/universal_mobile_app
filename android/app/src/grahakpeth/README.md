# grahakpeth flavor — Firebase config needed

This flavor's `applicationId` is `com.grahakpeth.app`. Before it can build,
add a `google-services.json` here (this directory) for an Android app
registered under that package name in the Firebase project used for push
notifications.

Without it, `./gradlew assembleGrahakpethDebug` (and the matching
`flutter build ... --flavor grahakpeth`) fails at the
`com.google.gms.google-services` step with "No matching client found for
package name 'com.grahakpeth.app'".

Optional: drop `mipmap-*/launcher_icon.png` overrides in
`android/app/src/grahakpeth/res/` for a tenant-specific app icon; otherwise
the shared icon in `src/main/res` is used.
