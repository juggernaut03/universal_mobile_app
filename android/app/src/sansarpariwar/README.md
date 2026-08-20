# sansarpariwar flavor — Firebase config needed

This flavor's `applicationId` is `com.sansarpariwar.app`. Before it can
build, add a `google-services.json` here (this directory) for an Android app
registered under that package name in the Firebase project used for push
notifications.

Without it, `./gradlew assembleSansarpariwarDebug` (and the matching
`flutter build ... --flavor sansarpariwar`) fails at the
`com.google.gms.google-services` step with "No matching client found for
package name 'com.sansarpariwar.app'".

Optional: drop `mipmap-*/launcher_icon.png` overrides in
`android/app/src/sansarpariwar/res/` for a tenant-specific app icon;
otherwise the shared icon in `src/main/res` is used.
