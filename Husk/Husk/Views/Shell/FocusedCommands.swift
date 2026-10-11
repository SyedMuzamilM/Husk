import SwiftUI

private struct HuskCleanModelKey: FocusedValueKey {
    typealias Value = CleanViewModel
}

extension FocusedValues {
    var huskCleanModel: CleanViewModel? {
        get { self[HuskCleanModelKey.self] }
        set { self[HuskCleanModelKey.self] = newValue }
    }
}
