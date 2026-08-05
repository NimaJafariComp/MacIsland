//
//  ApplicationRelauncher.swift
//  boringNotch
//
//  Created by Corentin132 on 03/10/2025.
//

import AppKit

enum ApplicationRelauncher {
    static func restart() {
        // Launch Services may return the current instance for a bundle-ID
        // lookup. Starting that request and immediately terminating can then
        // leave no MacIsland process at all. Launch the exact running bundle
        // after this process exits instead.
        let relaunchHelper = Process()
        relaunchHelper.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunchHelper.arguments = [
            "-c",
            "sleep 0.5; exec /usr/bin/open -n \"$1\"",
            "MacIslandRelauncher",
            Bundle.main.bundleURL.path
        ]

        do {
            try relaunchHelper.run()
        } catch {
            // Do not terminate the usable current app if the handoff cannot
            // be started (for example, if the bundle was moved mid-session).
            return
        }

        NSApplication.shared.terminate(nil)
    }
}
