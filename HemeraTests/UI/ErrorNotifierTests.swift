import Testing
@testable import Hemera

@MainActor
struct ErrorNotifierTests {

    @Test
    func showError_setsCurrentToast() {
        let notifier = ErrorNotifier()
        notifier.showError("Test error")
        #expect(notifier.currentToast?.message == "Test error")
    }

    @Test
    func showError_setsDefaultIcon() {
        let notifier = ErrorNotifier()
        notifier.showError("Test")
        #expect(notifier.currentToast?.icon == "exclamationmark.circle.fill")
    }

    @Test
    func showError_setsCustomIcon() {
        let notifier = ErrorNotifier()
        notifier.showError("Test", icon: "wifi.slash")
        #expect(notifier.currentToast?.icon == "wifi.slash")
    }

    @Test
    func showError_replacesExistingToast() {
        let notifier = ErrorNotifier()
        notifier.showError("First")
        notifier.showError("Second")
        #expect(notifier.currentToast?.message == "Second")
    }

    @Test
    func dismiss_clearsToast() {
        let notifier = ErrorNotifier()
        notifier.showError("Test")
        notifier.dismiss()
        #expect(notifier.currentToast == nil)
    }

    @Test
    func showError_autoDismissesAfterDelay() async {
        let notifier = ErrorNotifier(autoDismissDelay: .milliseconds(50))
        notifier.showError("Test")
        await notifier.dismissTask?.value
        #expect(notifier.currentToast == nil)
    }

    // MARK: - syncFailed

    @Test
    func syncFailed_defaultsToFalse() {
        let notifier = ErrorNotifier()
        #expect(notifier.syncFailed == false)
    }

    @Test
    func markSyncFailed_setsSyncFailedTrue() {
        let notifier = ErrorNotifier()
        notifier.markSyncFailed()
        #expect(notifier.syncFailed == true)
    }

    @Test
    func clearSyncFailed_resetsSyncFailedToFalse() {
        let notifier = ErrorNotifier()
        notifier.markSyncFailed()
        notifier.clearSyncFailed()
        #expect(notifier.syncFailed == false)
    }
}
