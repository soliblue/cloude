import Foundation
import IOKit.pwr_mgt

final class SleepPreventionService {
    static let shared = SleepPreventionService()
    static let defaultsKey = "preventIdleSystemSleep"

    private var assertionID = IOPMAssertionID(0)

    private init() {}

    deinit {
        releaseAssertion()
    }

    func applyStoredPreference() {
        setEnabled(UserDefaults.standard.bool(forKey: Self.defaultsKey))
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            if assertionID == 0 {
                var createdAssertionID = IOPMAssertionID(0)
                if IOPMAssertionCreateWithName(
                    kIOPMAssertPreventUserIdleSystemSleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "Cloude Agent remote access" as CFString,
                    &createdAssertionID
                ) == kIOReturnSuccess {
                    assertionID = createdAssertionID
                } else {
                    NSLog("SleepPreventionService: failed to create power assertion")
                }
            }
        } else {
            releaseAssertion()
        }
        return assertionID != 0
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            if IOPMAssertionRelease(assertionID) != kIOReturnSuccess {
                NSLog("SleepPreventionService: failed to release power assertion")
            }
            assertionID = IOPMAssertionID(0)
        }
    }
}
