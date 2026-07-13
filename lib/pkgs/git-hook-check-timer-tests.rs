use super::*;

fn warning_at(nanoseconds: u64) -> Option<String> {
    slow_check_warning(
        OsStr::new("check_boundary"),
        Duration::from_nanos(nanoseconds),
    )
}

#[test]
fn does_not_warn_below_one_second() {
    assert_eq!(warning_at(999_999_999), None);
}

#[test]
fn does_not_warn_at_exactly_one_second() {
    assert_eq!(warning_at(1_000_000_000), None);
}

#[test]
fn barely_slow_check_does_not_display_one_second() {
    assert_eq!(
        warning_at(1_000_000_001),
        Some("flakebox: warning: check_boundary took 1.001s (>1s)".to_owned())
    );
}

#[test]
fn rounds_display_to_millisecond_precision() {
    assert_eq!(
        warning_at(1_234_567_890),
        Some("flakebox: warning: check_boundary took 1.235s (>1s)".to_owned())
    );
}

#[cfg(unix)]
#[test]
fn signal_before_child_publication_is_queued_for_publisher() {
    let state = ChildSignalState::new();
    assert_eq!(state.receive(TERMINATE_SIGNAL), None);
    assert_eq!(state.publish(1234), Some(TERMINATE_SIGNAL));
}

#[cfg(unix)]
#[test]
fn signal_after_child_publication_is_routed_to_published_group() {
    let state = ChildSignalState::new();
    assert_eq!(state.publish(1234), None);
    assert_eq!(state.receive(TERMINATE_SIGNAL), Some(1234));
}

#[cfg(unix)]
#[test]
fn signal_during_shutdown_is_not_routed_to_finished_child() {
    let state = ChildSignalState::new();
    state.begin_shutdown();
    assert_eq!(state.receive(TERMINATE_SIGNAL), None);
    assert_eq!(state.encoded.load(Ordering::SeqCst), SHUTTING_DOWN);
}
