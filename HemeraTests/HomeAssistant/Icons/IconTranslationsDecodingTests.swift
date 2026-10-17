import Foundation
import HAKit
import Testing
@testable import Hemera

@MainActor
struct IconTranslationsDecodingTests {

    /// Mirrors the real `frontend/get_icons` response for `category: "entity_component"`.
    private func response() -> HAData {
        HAData(value: [
            "resources": [
                "cover": [
                    "_": ["default": "mdi:window-open", "state": ["closed": "mdi:window-closed"]],
                    "garage": ["default": "mdi:garage-open", "state": ["closed": "mdi:garage"]]
                ],
                "climate": [
                    "_": [
                        "default": "mdi:thermostat",
                        "state_attributes": [
                            "hvac_action": [
                                "default": "mdi:circle-medium",
                                "state": ["cooling": "mdi:snowflake", "heating": "mdi:fire"]
                            ]
                        ]
                    ]
                ]
            ]
        ])
    }

    @Test func init_haData_decodesDeviceClassEntries() throws {
        let translations = try #require(IconTranslations(haData: response()))

        #expect(translations.entry(domain: "cover", deviceClass: "garage")?.defaultIcon == "mdi:garage-open")
        #expect(translations.entry(domain: "cover", deviceClass: "garage")?.state?["closed"] == "mdi:garage")
    }

    @Test func init_haData_decodesDomainFallbackEntry() throws {
        let translations = try #require(IconTranslations(haData: response()))
        #expect(translations.entry(domain: "cover", deviceClass: nil)?.defaultIcon == "mdi:window-open")
    }

    @Test func init_haData_decodesNestedStateAttributes() throws {
        let translations = try #require(IconTranslations(haData: response()))
        let action = translations.entry(domain: "climate", deviceClass: nil)?.stateAttributes?["hvac_action"]

        #expect(action?.state?["heating"] == "mdi:fire")
        #expect(action?.defaultIcon == "mdi:circle-medium")
    }

    @Test func init_haData_missingResourcesKey_returnsNil() {
        #expect(IconTranslations(haData: HAData(value: ["unexpected": [:]])) == nil)
    }

    @Test func init_haData_nonDictionaryPayload_returnsNil() {
        #expect(IconTranslations(haData: HAData(value: ["resources"])) == nil)
    }

    /// Round-trips through the on-disk representation the cache uses.
    @Test func codable_roundTripsThroughJSON() throws {
        let original = try #require(IconTranslations(haData: response()))
        let decoded = try JSONDecoder().decode(
            IconTranslations.self,
            from: try JSONEncoder().encode(original)
        )
        #expect(decoded == original)
    }
}
