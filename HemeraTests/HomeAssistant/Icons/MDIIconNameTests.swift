import Mortar
import Testing
@testable import Hemera

@MainActor
struct MDIIconNameTests {

    @Test func normalised_stripsMdiPrefix() {
        #expect(MDIIconName.normalised("mdi:garage") == "garage")
    }

    @Test func normalised_stripsLegacyHassPrefix() {
        #expect(MDIIconName.normalised("hass:garage") == "garage")
    }

    @Test func normalised_bareName_passesThrough() {
        #expect(MDIIconName.normalised("garage") == "garage")
    }

    @Test func normalised_isIdempotent() {
        let once = MDIIconName.normalised("mdi:garage")
        #expect(once.flatMap(MDIIconName.normalised) == "garage")
    }

    /**
     Custom icon packs cannot be served from the MDI CDN, so they must be rejected before they turn
     into a request that can only 404.
    */
    @Test func normalised_unsupportedIconPack_returnsNil() {
        #expect(MDIIconName.normalised("phu:floor-lamp") == nil)
        #expect(MDIIconName.normalised("si:home-assistant") == nil)
    }

    @Test func normalised_emptyOrPrefixOnly_returnsNil() {
        #expect(MDIIconName.normalised("") == nil)
        #expect(MDIIconName.normalised("   ") == nil)
        #expect(MDIIconName.normalised("mdi:") == nil)
    }
}
