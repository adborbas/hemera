import Foundation

/**
 What happens when an address is submitted.

 The two screens diverge entirely here — one starts an OAuth flow, the other validates the
 address and persists it — so each reports whether its attempt was accepted rather than the
 view inferring it.
*/
@MainActor
protocol ServerAddressHandling: AnyObject, Observable {
    var text: String { get set }
    var mode: ServerAddressMode { get }
    var isBusy: Bool { get }
    var canSubmit: Bool { get }
    var errorMessage: String? { get }

    /// Returns whether the address was accepted. On rejection the handler shows why via `errorMessage`.
    func submit() async -> Bool
}
