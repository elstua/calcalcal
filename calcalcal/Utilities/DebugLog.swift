import Foundation
import os.log

/// Debug-only print helper.
///
/// Behaves like Swift's global `print(...)` in Debug builds and compiles to a
/// no-op in Release builds, so console logging cannot leak into production.
///
/// Migration history: every `print(...)` call in the app source was renamed to
/// `dlog(...)` in PR #2 of the perf triage (2026-05-20). New code should prefer
/// `os.Logger` from `os.log` for anything we want to keep in Release.
@inlinable
public func dlog(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {
    #if DEBUG
    // Reconstruct the same output `print` would produce.
    let line = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(line, terminator: terminator)
    #endif
}
