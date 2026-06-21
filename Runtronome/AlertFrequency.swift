import Foundation

enum AlertFrequency: String, CaseIterable, Identifiable {
    case everyStep   = "EVERY STEP"
    case everyOther  = "EVERY OTHER"
    case every3rd    = "EVERY 3RD"
    case every4th    = "EVERY 4TH"
    case every5th    = "EVERY 5TH"
    case every6th    = "EVERY 6TH"

    var id: String { rawValue }

    var stepInterval: Int {
        switch self {
        case .everyStep:  return 1
        case .everyOther: return 2
        case .every3rd:   return 3
        case .every4th:   return 4
        case .every5th:   return 5
        case .every6th:   return 6
        }
    }
}
