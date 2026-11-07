import Foundation

/// Yields until `condition` holds or `timeout` passes, so tests don't depend on a fixed sleep.
/// Callers assert the outcome afterwards.
@MainActor
func waitUntil(timeout: Duration = .seconds(5), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition(), ContinuousClock.now < deadline { await Task.yield() }
}
