#!/bin/sh
set -eu
source_plist="$SRCROOT/QiuJi/Resources/Info.plist"
output_plist="$DERIVED_FILE_DIR/CuePhys-Info.plist"
if [ "$CONFIGURATION" != Debug ]; then
    # Use the same Foundation parser as the shipped app. Do not print the URL.
    {
        cat "$SRCROOT/QiuJi/Core/Extensions/AppConfig.swift"
        cat <<'SWIFT'
guard AppConfig.validatedAPIBaseURL(ProcessInfo.processInfo.environment["API_BASE_URL"], release: true) != nil else {
    FileHandle.standardError.write(Data("error: Release API_BASE_URL must be an HTTPS endpoint on cuephys.com.\n".utf8))
    exit(1)
}
SWIFT
    } | SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" xcrun --sdk macosx swift -
fi
# Frozen build snapshots are read-only. The generated plist must be writable.
/usr/bin/install -m 644 "$source_plist" "$output_plist"
if [ "$CONFIGURATION" = Debug ]; then
    # Keep the existing test server reachable only in development builds.
    /usr/bin/plutil -insert NSAppTransportSecurity -xml '<dict><key>NSExceptionDomains</key><dict><key>106.54.3.210</key><dict><key>NSExceptionAllowsInsecureHTTPLoads</key><true/></dict></dict></dict>' "$output_plist"
fi
