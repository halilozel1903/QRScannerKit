import Foundation

/// What a scanned code means: a link, a Wi-Fi network, a contact, a place, a message or text.
///
/// `ScanPayload(parsing:)` understands the formats phones and code generators write:
///
/// | Content | Example |
/// | --- | --- |
/// | URL | `https://example.com`, `www.example.com`, `myapp://open` |
/// | Wi-Fi | `WIFI:T:WPA;S:Guest;P:pa\;ss;H:false;;` |
/// | Contact | `BEGIN:VCARD` … `END:VCARD`, `MECARD:N:Doe,Jane;TEL:+1555;;` |
/// | Location | `geo:37.7749,-122.4194?q=Ferry%20Building` |
/// | Email | `mailto:hi@example.com?subject=Hello`, `MATMSG:TO:…;SUB:…;BODY:…;;` |
/// | Phone | `tel:+15551234567` |
/// | SMS | `sms:+15551234567?body=Hi`, `SMSTO:+15551234567:Hi` |
///
/// Anything else is `.text`.
public enum ScanPayload: Hashable, Sendable {
    case url(URL)
    case wifi(WiFiNetwork)
    case contact(Contact)
    case location(GeoLocation)
    case email(Email)
    case phone(String)
    case sms(SMS)
    case text(String)

    /// Parses the string a code contains.
    public init(parsing string: String) {
        self = PayloadParser.parse(string)
    }

    /// The kind of payload, without its values.
    public var kind: Kind {
        switch self {
        case .url: .url
        case .wifi: .wifi
        case .contact: .contact
        case .location: .location
        case .email: .email
        case .phone: .phone
        case .sms: .sms
        case .text: .text
        }
    }

    /// A one-line description for lists: the address, network name, person or text.
    public var summary: String {
        switch self {
        case .url(let url):
            return url.absoluteString
        case .wifi(let network):
            return network.ssid
        case .contact(let contact):
            return contact.displayName
        case .location(let location):
            return location.query ?? location.coordinateText
        case .email(let email):
            return email.subject.map { "\(email.address) · \($0)" } ?? email.address
        case .phone(let number):
            return number
        case .sms(let sms):
            return sms.body.map { "\(sms.number) · \($0)" } ?? sms.number
        case .text(let text):
            return text
        }
    }

    /// A URL that opens the payload in the system app it belongs to: the link itself, Mail,
    /// Phone, Messages or Maps. `nil` for Wi-Fi networks, contacts and text.
    public var actionURL: URL? {
        switch self {
        case .url(let url):
            return url
        case .email(let email):
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = email.address
            var items: [URLQueryItem] = []
            if let subject = email.subject { items.append(URLQueryItem(name: "subject", value: subject)) }
            if let body = email.body { items.append(URLQueryItem(name: "body", value: body)) }
            components.queryItems = items.isEmpty ? nil : items
            return components.url
        case .phone(let number):
            return URL(string: "tel:\(PayloadParser.dialable(number))")
        case .sms(let sms):
            var components = URLComponents()
            components.scheme = "sms"
            components.path = PayloadParser.dialable(sms.number)
            if let body = sms.body { components.queryItems = [URLQueryItem(name: "body", value: body)] }
            return components.url
        case .location(let location):
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)"),
            ] + (location.query.map { [URLQueryItem(name: "q", value: $0)] } ?? [])
            return components?.url
        case .wifi, .contact, .text:
            return nil
        }
    }

    /// The kinds of payload.
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case url, wifi, contact, location, email, phone, sms, text

        /// A title for the kind, for example "Wi-Fi Network".
        public var title: String {
            switch self {
            case .url: "Website"
            case .wifi: "Wi-Fi Network"
            case .contact: "Contact"
            case .location: "Location"
            case .email: "Email"
            case .phone: "Phone Number"
            case .sms: "Text Message"
            case .text: "Text"
            }
        }

        /// The SF Symbol for the kind.
        public var systemImage: String {
            switch self {
            case .url: "safari"
            case .wifi: "wifi"
            case .contact: "person.crop.circle"
            case .location: "mappin.and.ellipse"
            case .email: "envelope"
            case .phone: "phone"
            case .sms: "message"
            case .text: "text.alignleft"
            }
        }
    }
}

/// A Wi-Fi network from a `WIFI:` code.
public struct WiFiNetwork: Hashable, Sendable {
    public enum Security: String, Hashable, Sendable {
        /// WPA, WPA2 or WPA2/WPA3 personal.
        case wpa
        /// WPA3 personal only (`SAE`).
        case wpa3
        case wep
        /// No password.
        case open

        /// "WPA/WPA2", "WPA3", "WEP" or "None".
        public var name: String {
            switch self {
            case .wpa: "WPA/WPA2"
            case .wpa3: "WPA3"
            case .wep: "WEP"
            case .open: "None"
            }
        }
    }

    /// The network name.
    public var ssid: String
    /// The password, `nil` for open networks.
    public var password: String?
    public var security: Security
    /// `true` when the network does not broadcast its name.
    public var isHidden: Bool

    public init(ssid: String, password: String? = nil, security: Security = .wpa, isHidden: Bool = false) {
        self.ssid = ssid
        self.password = password
        self.security = security
        self.isHidden = isHidden
    }
}

/// A contact card from a vCard or MECARD code.
public struct Contact: Hashable, Sendable {
    public var name: String?
    public var organization: String?
    public var jobTitle: String?
    public var phoneNumbers: [String]
    public var emails: [String]
    public var urls: [String]
    public var address: String?
    public var note: String?

    public init(
        name: String? = nil,
        organization: String? = nil,
        jobTitle: String? = nil,
        phoneNumbers: [String] = [],
        emails: [String] = [],
        urls: [String] = [],
        address: String? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.organization = organization
        self.jobTitle = jobTitle
        self.phoneNumbers = phoneNumbers
        self.emails = emails
        self.urls = urls
        self.address = address
        self.note = note
    }

    /// The name, else the organization, else the first email or phone number.
    public var displayName: String {
        name ?? organization ?? emails.first ?? phoneNumbers.first ?? "Contact"
    }
}

/// A place from a `geo:` URI.
public struct GeoLocation: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?
    /// The `q=` label or search, if the code has one.
    public var query: String?

    public init(latitude: Double, longitude: Double, altitude: Double? = nil, query: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.query = query
    }

    /// The coordinate with five decimals, for example "37.77490, -122.41940".
    public var coordinateText: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}

/// An email draft from a `mailto:` or `MATMSG:` code.
public struct Email: Hashable, Sendable {
    public var address: String
    public var subject: String?
    public var body: String?

    public init(address: String, subject: String? = nil, body: String? = nil) {
        self.address = address
        self.subject = subject
        self.body = body
    }
}

/// A text message draft from an `sms:` or `SMSTO:` code.
public struct SMS: Hashable, Sendable {
    public var number: String
    public var body: String?

    public init(number: String, body: String? = nil) {
        self.number = number
        self.body = body
    }
}
