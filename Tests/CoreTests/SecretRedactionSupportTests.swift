import Foundation
import Testing
@testable import BosCore

@Suite
struct SecretRedactionSupportTests {
    @Test func usesFirstKeyWhenMultipleEnvironmentKeysCarrySameSecret() {
        let redacted = SecretRedactionSupport.redact(
            "private=c3VwZXItc2VjcmV0 password=match-secret",
            environment: [
                "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                "ASC_PRIVATE_KEY_B64": "c3VwZXItc2VjcmV0",
                "MATCH_PASSWORD": "match-secret"
            ],
            keys: ["ASC_KEY_P8_BASE64", "ASC_PRIVATE_KEY_B64", "MATCH_PASSWORD"]
        )

        #expect(redacted == "private=<redacted:ASC_KEY_P8_BASE64> password=<redacted:MATCH_PASSWORD>")
    }

    @Test func ignoresMissingAndEmptySecrets() {
        let redacted = SecretRedactionSupport.redact(
            "private=secret password=",
            environment: [
                "ASC_KEY_P8_BASE64": "secret",
                "MATCH_PASSWORD": ""
            ],
            keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
        )

        #expect(redacted == "private=<redacted:ASC_KEY_P8_BASE64> password=")
    }
}
