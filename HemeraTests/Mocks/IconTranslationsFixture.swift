import Foundation
@testable import Hemera

/**
 Icon translations fixture mirroring the real values Home Assistant ships for the domains Hemera
 renders.

 Written out by hand rather than loaded from the bundled resource on purpose: regenerating the
 bundle should never silently change what these tests assert.
*/
@MainActor
enum IconTranslationsFixture {

    static func resolver() -> IconResolver {
        IconResolver(translations: translations)
    }

    static let translations = IconTranslations(resources: [
        "light": [
            "_": .init(defaultIcon: "mdi:lightbulb", state: ["off": "mdi:lightbulb-off"])
        ],
        "switch": [
            "_": .init(defaultIcon: "mdi:toggle-switch-variant", state: ["off": "mdi:toggle-switch-variant-off"]),
            "switch": .init(defaultIcon: "mdi:toggle-switch-variant", state: ["off": "mdi:toggle-switch-variant-off"]),
            "outlet": .init(defaultIcon: "mdi:power-plug", state: ["off": "mdi:power-plug-off"])
        ],
        "button": [
            "_": .init(defaultIcon: "mdi:button-pointer"),
            "restart": .init(defaultIcon: "mdi:restart"),
            "update": .init(defaultIcon: "mdi:package-up"),
            "identify": .init(defaultIcon: "mdi:crosshairs-question")
        ],
        "automation": [
            "_": .init(
                defaultIcon: "mdi:robot",
                state: ["off": "mdi:robot-off", "unavailable": "mdi:robot-confused"]
            )
        ],
        "scene": [
            "_": .init(defaultIcon: "mdi:palette")
        ],
        "script": [
            "_": .init(defaultIcon: "mdi:script-text", state: ["on": "mdi:script-text-play"])
        ],
        "binary_sensor": [
            "_": .init(defaultIcon: "mdi:radiobox-blank", state: ["on": "mdi:checkbox-marked-circle"]),
            "motion": .init(defaultIcon: "mdi:motion-sensor-off", state: ["on": "mdi:motion-sensor"]),
            "door": .init(defaultIcon: "mdi:door-closed", state: ["on": "mdi:door-open"]),
            "window": .init(defaultIcon: "mdi:window-closed", state: ["on": "mdi:window-open"]),
            "moisture": .init(defaultIcon: "mdi:water-off", state: ["on": "mdi:water"]),
            "smoke": .init(defaultIcon: "mdi:smoke-detector-variant", state: ["on": "mdi:smoke-detector-variant-alert"])
        ],
        "cover": [
            "_": .init(
                defaultIcon: "mdi:window-open",
                state: ["closed": "mdi:window-closed", "closing": "mdi:arrow-down-box", "opening": "mdi:arrow-up-box"]
            ),
            "garage": .init(
                defaultIcon: "mdi:garage-open",
                state: ["closed": "mdi:garage", "closing": "mdi:arrow-down-box", "opening": "mdi:arrow-up-box"]
            ),
            "blind": .init(
                defaultIcon: "mdi:blinds-horizontal",
                state: ["closed": "mdi:blinds-horizontal-closed", "closing": "mdi:arrow-down-box", "opening": "mdi:arrow-up-box"]
            )
        ],
        "climate": [
            "_": .init(
                defaultIcon: "mdi:thermostat",
                stateAttributes: [
                    "hvac_action": .init(
                        defaultIcon: "mdi:circle-medium",
                        state: [
                            "cooling": "mdi:snowflake",
                            "heating": "mdi:fire",
                            "drying": "mdi:water-percent",
                            "fan": "mdi:fan",
                            "idle": "mdi:clock-outline",
                            "off": "mdi:power",
                            "defrosting": "mdi:snowflake-melt",
                            "preheating": "mdi:heat-wave"
                        ]
                    )
                ]
            )
        ]
    ])
}
