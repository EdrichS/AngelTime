import Observation

/// Runs `track` and calls `onChange` (on the main actor, after the change has landed) each time
/// an observable property that `track` read is modified. It keeps tracking until the closures
/// stop reading observable state, for example after a `weak self` has gone away.
@MainActor
func observe(_ track: @escaping @MainActor () -> Void, onChange: @escaping @MainActor () -> Void) {
    withObservationTracking {
        track()
    } onChange: {
        Task { @MainActor in
            onChange()
            observe(track, onChange: onChange)
        }
    }
}

/// Runs `body` now, and again whenever any observable property it read changes.
/// Used to bridge `@Observable` state into AppKit (status item, window titles, etc).
@MainActor
func observeAndApply(_ body: @escaping @MainActor () -> Void) {
    observe(body, onChange: {})
}
