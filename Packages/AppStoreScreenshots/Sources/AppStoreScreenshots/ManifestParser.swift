import Foundation

struct ManifestEntry: Decodable {
    let attachments: [Attachment]
    let testIdentifier: String

    struct Attachment: Decodable {
        let exportedFileName: String
        let suggestedHumanReadableName: String
    }
}

public struct ResolvedScreenshot {
    public let name: String
    public let filePath: URL
}

public enum ManifestParser {

    public static func load(from deviceDir: URL) throws -> [ResolvedScreenshot] {
        let manifestURL = deviceDir.appending(path: "manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let entries = try JSONDecoder().decode([ManifestEntry].self, from: data)

        return entries.compactMap { entry in
            guard let attachment = entry.attachments.first else { return nil }

            // suggestedHumanReadableName format: "01_Home_Portrait_0_UUID.png"
            // Extract the name prefix before the "_0_" suffix
            let humanName = attachment.suggestedHumanReadableName
            let name: String
            if let range = humanName.range(of: "_0_", options: .backwards) {
                name = String(humanName[humanName.startIndex..<range.lowerBound])
            } else {
                name = humanName.replacingOccurrences(of: ".png", with: "")
            }

            let filePath = deviceDir.appending(path: attachment.exportedFileName)
            return ResolvedScreenshot(name: name, filePath: filePath)
        }
    }
}
