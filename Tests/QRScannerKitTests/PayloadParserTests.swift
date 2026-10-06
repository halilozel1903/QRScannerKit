import Foundation
import Testing
@testable import QRScannerKit

@Suite("URLs and text")
struct URLPayloadTests {
    @Test func httpsURL() {
        let payload = ScanPayload(parsing: "https://example.com/menu?table=4")
        #expect(payload == .url(URL(string: "https://example.com/menu?table=4")!))
        #expect(payload.kind == .url)
        #expect(payload.actionURL == URL(string: "https://example.com/menu?table=4"))
    }

    @Test func schemeIsCaseInsensitiveAndWhitespaceIsTrimmed() {
        let payload = ScanPayload(parsing: "  HTTP://EXAMPLE.COM\n")
        #expect(payload.kind == .url)
    }

    @Test func wwwGetsHTTPS() {
        #expect(ScanPayload(parsing: "www.example.com") == .url(URL(string: "https://www.example.com")!))
    }

    @Test func customSchemes() {
        #expect(ScanPayload(parsing: "myapp://open/item/42").kind == .url)
        #expect(ScanPayload(parsing: "otpauth://totp/Example:jane?secret=JBSWY3DPEHPK3PXP").kind == .url)
    }

    @Test func textStaysText() {
        #expect(ScanPayload(parsing: "Hello, world") == .text("Hello, world"))
        #expect(ScanPayload(parsing: "4006381333931") == .text("4006381333931"))
        #expect(ScanPayload(parsing: "see https://example.com") == .text("see https://example.com"))
        #expect(ScanPayload(parsing: "12:30") == .text("12:30"))
        #expect(ScanPayload(parsing: "") == .text(""))
    }

    @Test func bareEmailAddress() {
        #expect(ScanPayload(parsing: "jane@example.com") == .email(Email(address: "jane@example.com")))
        #expect(ScanPayload(parsing: "jane@localhost").kind == .text)
        #expect(ScanPayload(parsing: "@example.com").kind == .text)
    }
}

@Suite("Wi-Fi")
struct WiFiPayloadTests {
    @Test func wpaNetwork() {
        let payload = ScanPayload(parsing: "WIFI:T:WPA;S:Harbor Café Guest;P:flatwhite2026;;")
        #expect(payload == .wifi(WiFiNetwork(ssid: "Harbor Café Guest", password: "flatwhite2026", security: .wpa)))
        #expect(payload.summary == "Harbor Café Guest")
        #expect(payload.actionURL == nil)
    }

    @Test func fieldsInAnyOrderAndLowercasePrefix() {
        let payload = ScanPayload(parsing: "wifi:P:secret;H:true;S:Attic;T:WPA2;;")
        #expect(payload == .wifi(WiFiNetwork(ssid: "Attic", password: "secret", security: .wpa, isHidden: true)))
    }

    @Test func escapedCharacters() {
        let payload = ScanPayload(parsing: #"WIFI:T:WPA;S:My\;Net\:work;P:pa\\ss\,word\";;"#)
        guard case .wifi(let network) = payload else {
            Issue.record("Expected a Wi-Fi payload, got \(payload)")
            return
        }
        #expect(network.ssid == "My;Net:work")
        #expect(network.password == #"pa\ss,word""#)
    }

    @Test func quotedSSID() {
        let payload = ScanPayload(parsing: #"WIFI:S:"Lobby";T:WPA;P:"open sesame";;"#)
        #expect(payload == .wifi(WiFiNetwork(ssid: "Lobby", password: "open sesame", security: .wpa)))
    }

    @Test func openNetworkDropsPassword() {
        #expect(ScanPayload(parsing: "WIFI:T:nopass;S:Library;P:;;") == .wifi(WiFiNetwork(ssid: "Library", security: .open)))
        #expect(ScanPayload(parsing: "WIFI:S:Library;;") == .wifi(WiFiNetwork(ssid: "Library", security: .open)))
    }

    @Test func missingTypeWithPasswordIsWPA() {
        #expect(ScanPayload(parsing: "WIFI:S:Studio;P:hunter22;;") == .wifi(WiFiNetwork(ssid: "Studio", password: "hunter22", security: .wpa)))
    }

    @Test func wepAndWPA3() {
        #expect(ScanPayload(parsing: "WIFI:T:WEP;S:Old;P:12345;;") == .wifi(WiFiNetwork(ssid: "Old", password: "12345", security: .wep)))
        #expect(ScanPayload(parsing: "WIFI:T:SAE;S:New;P:abcdefgh;;") == .wifi(WiFiNetwork(ssid: "New", password: "abcdefgh", security: .wpa3)))
    }

    @Test func missingSSIDIsText() {
        #expect(ScanPayload(parsing: "WIFI:T:WPA;P:secret;;").kind == .text)
        #expect(ScanPayload(parsing: "WIFI:S:;;").kind == .text)
    }

    @Test func splitKeepsEscapes() {
        #expect(PayloadParser.split(#"a\;b;c"#, on: ";") == [#"a\;b"#, "c"])
        #expect(PayloadParser.split("k:v:w", on: ":", maxSplits: 1) == ["k", "v:w"])
        #expect(PayloadParser.unescape(#"a\;b\\c\"#) == #"a;b\c\"#)
    }
}

@Suite("Contacts")
struct ContactPayloadTests {
    @Test func vCard3() {
        let vCard = """
        BEGIN:VCARD
        VERSION:3.0
        N:Doe;Jane;;Dr.;
        FN:Dr. Jane Doe
        ORG:Harbor Café;Front of House
        TITLE:Manager
        TEL;TYPE=CELL:+1 555 123 4567
        TEL;TYPE=WORK:+1 555 765 4321
        EMAIL;TYPE=INTERNET:jane@example.com
        URL:https://example.com
        ADR;TYPE=WORK:;;1 Pier Road;San Francisco;CA;94111;USA
        NOTE:Ask for the window table\\, please
        END:VCARD
        """
        let payload = ScanPayload(parsing: vCard)
        let expected = Contact(
            name: "Dr. Jane Doe",
            organization: "Harbor Café, Front of House",
            jobTitle: "Manager",
            phoneNumbers: ["+1 555 123 4567", "+1 555 765 4321"],
            emails: ["jane@example.com"],
            urls: ["https://example.com"],
            address: "1 Pier Road, San Francisco, CA, 94111, USA",
            note: "Ask for the window table, please"
        )
        #expect(payload == .contact(expected))
        #expect(payload.summary == "Dr. Jane Doe")
    }

    @Test func vCardWithoutFNUsesStructuredName() {
        let payload = ScanPayload(parsing: "BEGIN:VCARD\r\nVERSION:2.1\r\nN:Smith;John\r\nitem1.TEL:+15550000\r\nEND:VCARD")
        #expect(payload == .contact(Contact(name: "John Smith", phoneNumbers: ["+15550000"])))
    }

    @Test func vCardFoldedLines() {
        let payload = ScanPayload(parsing: "BEGIN:VCARD\nFN:Ada\nNOTE:First line\n  continues here\nEND:VCARD")
        guard case .contact(let contact) = payload else {
            Issue.record("Expected a contact")
            return
        }
        #expect(contact.note == "First line continues here")
    }

    @Test func meCard() {
        let payload = ScanPayload(parsing: #"MECARD:N:Doe,Jane;TEL:+15551234567;EMAIL:jane@example.com;NOTE:Hi\; there;;"#)
        #expect(payload == .contact(Contact(
            name: "Jane Doe",
            phoneNumbers: ["+15551234567"],
            emails: ["jane@example.com"],
            note: "Hi; there"
        )))
    }

    @Test func emptyCardsAreText() {
        #expect(ScanPayload(parsing: "MECARD:;;").kind == .text)
        #expect(ScanPayload(parsing: "BEGIN:VCARD\nEND:VCARD").kind == .text)
    }
}

@Suite("Location, email, phone and SMS")
struct MessagePayloadTests {
    @Test func geo() {
        let payload = ScanPayload(parsing: "geo:37.7955,-122.3937?q=Ferry%20Building")
        #expect(payload == .location(GeoLocation(latitude: 37.7955, longitude: -122.3937, query: "Ferry Building")))
        #expect(payload.summary == "Ferry Building")
        #expect(payload.actionURL?.host == "maps.apple.com")
    }

    @Test func geoWithAltitudeAndParameters() {
        let payload = ScanPayload(parsing: "GEO:48.2010,16.3695,183;crs=wgs84;u=40")
        #expect(payload == .location(GeoLocation(latitude: 48.201, longitude: 16.3695, altitude: 183)))
        #expect(GeoLocation(latitude: 48.201, longitude: 16.3695).coordinateText == "48.20100, 16.36950")
    }

    @Test func invalidGeoIsText() {
        #expect(ScanPayload(parsing: "geo:200,10").kind == .text)
        #expect(ScanPayload(parsing: "geo:abc").kind == .text)
    }

    @Test func mailto() {
        let payload = ScanPayload(parsing: "mailto:hello@example.com?subject=Table%20for%20two&body=Tonight+at+8")
        #expect(payload == .email(Email(address: "hello@example.com", subject: "Table for two", body: "Tonight at 8")))
        #expect(payload.actionURL?.scheme == "mailto")
    }

    @Test func matmsg() {
        let payload = ScanPayload(parsing: "MATMSG:TO:hello@example.com;SUB:Hi;BODY:See you\; soon;;")
        #expect(payload == .email(Email(address: "hello@example.com", subject: "Hi", body: "See you; soon")))
    }

    @Test func tel() {
        let payload = ScanPayload(parsing: "tel:+1-555-123-4567")
        #expect(payload == .phone("+1-555-123-4567"))
        #expect(payload.actionURL == URL(string: "tel:+15551234567"))
    }

    @Test func sms() {
        #expect(ScanPayload(parsing: "sms:+15551234567?body=On%20my%20way") == .sms(SMS(number: "+15551234567", body: "On my way")))
        #expect(ScanPayload(parsing: "sms:+15551234567;?&body=Hi") == .sms(SMS(number: "+15551234567", body: "Hi")))
        #expect(ScanPayload(parsing: "SMSTO:+15551234567:Running late") == .sms(SMS(number: "+15551234567", body: "Running late")))
        #expect(ScanPayload(parsing: "smsto:+15551234567") == .sms(SMS(number: "+15551234567")))
    }

    @Test func kindTitlesAndSymbols() {
        for kind in ScanPayload.Kind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.systemImage.isEmpty)
        }
        #expect(ScanPayload.Kind.wifi.title == "Wi-Fi Network")
    }
}
