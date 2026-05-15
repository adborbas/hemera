import AppScreenshotKit

public enum TargetDevice: CaseIterable, Sendable {
    case iPhone69
    case iPhone63
    case iPad13

    public var directoryName: String {
        switch self {
        case .iPhone69: "iPhone-6.9"
        case .iPhone63: "iPhone-6.3"
        case .iPad13: "iPad-13"
        }
    }

    public func portraitSize() -> AppScreenshotSize {
        switch self {
        case .iPhone69:
            .iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868)
        case .iPhone63:
            .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622)
        case .iPad13:
            .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732)
        }
    }

    public func landscapeSize() -> AppScreenshotSize {
        switch self {
        case .iPhone69:
            .iPhone69Inch(model: .iPhone16ProMax(orientation: .landscape), size: .w2868h1320)
        case .iPhone63:
            .iPhone63Inch(model: .iPhone16Pro(orientation: .landscape), size: .w2622h1206)
        case .iPad13:
            .iPad130Inch(model: .iPadPro13M4(orientation: .landscape), size: .w2732h2048)
        }
    }

    public static func from(device: AppScreenshotDevice) -> TargetDevice? {
        switch device.model {
        case .iPhone16ProMax: .iPhone69
        case .iPhone16Pro: .iPhone63
        case .iPadPro13M4: .iPad13
        default: nil
        }
    }
}
