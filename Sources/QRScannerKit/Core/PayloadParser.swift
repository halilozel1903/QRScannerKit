import Foundation

/// Turns the raw string of a code into a `ScanPayload`. Pure and synchronous, so it is easy to test.
enum PayloadParser {
    static func parse(_ raw: String) -> ScanPayload {
        let string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = string.lowercased()

        if lowercased.hasPrefix("wifi:"), let network = wifi(string) {
            return .wifi(network)
        }
        if lowercased.hasPrefix("begin:vcard"), let contact = vCard(string) {
            return .contact(contact)
        }
        if lowercased.hasPrefix("mecard:"), let contact = meCard(string) {
            return .contact(contact)
        }
        if lowercased.hasPrefix("matmsg:"), let email = matMsg(string) {
            return .email(email)
        }
        if lowercased.hasPrefix("geo:"), let location = geo(string) {
            return .location(location)
        }
        if lowercased.hasPrefix("mailto:"), let email = mailto(string) {
            return .email(email)
        }
        if lowercased.hasPrefix("tel:") {
            let number = decode(String(string.dropFirst(4)))
            if !number.isEmpty { return .phone(number) }
        }
        if lowercased.hasPrefix("smsto:") || lowercased.hasPrefix("sms:") || lowercased.hasPrefix("mmsto:"),
           let message = sms(string) {
            return .sms(message)
        }
        if let link = url(string) {
            return .url(link)
        }
        if isEmailAddress(string) {
            return .email(Email(address: string))
        }
        return .text(raw)
    }

    // MARK: - Wi-Fi

    /// `WIFI:T:WPA;S:name;P:password;H:true;;`. Fields come in any order; `\`, `;`, `,`, `:` and `"`
    /// are escaped with a backslash.
    static func wifi(_ string: String) -> WiFiNetwork? {
        let values = fields(of: string.dropFirst("WIFI:".count))
        guard let rawSSID = values["S"] else { return nil }
        let ssid = unquoted(rawSSID)
        guard !ssid.isEmpty else { return nil }

        let password = values["P"].map(unquoted).nonEmpty
        let security: WiFiNetwork.Security = switch values["T"]?.uppercased() {
        case nil: password == nil ? .open : .wpa
        case "WEP"?: .wep
        case "SAE"?, "WPA3"?: .wpa3
        case ""?, "NOPASS"?, "NONE"?, "OPEN"?: .open
        default: .wpa
        }
        let hidden = (values["H"] ?? "").lowercased() == "true"
        return WiFiNetwork(
            ssid: ssid,
            password: security == .open ? nil : password,
            security: security,
            isHidden: hidden
        )
    }

    // MARK: - Contacts

    /// `MECARD:N:Doe,Jane;TEL:+15551234567;EMAIL:jane@example.com;;`
    static func meCard(_ string: String) -> Contact? {
        var contact = Contact()
        for field in split(string.dropFirst("MECARD:".count), on: ";") where !field.isEmpty {
            let pair = split(field, on: ":", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let key = pair[0].uppercased()
            let value = unescape(pair[1])
            guard !value.isEmpty else { continue }
            switch key {
            case "N":
                // "Last,First" -> "First Last"
                let parts = split(pair[1], on: ",").map(unescape).filter { !$0.isEmpty }
                contact.name = parts.count == 2 ? "\(parts[1]) \(parts[0])" : parts.joined(separator: " ")
            case "ORG": contact.organization = value
            case "TITLE": contact.jobTitle = value
            case "TEL": contact.phoneNumbers.append(value)
            case "EMAIL": contact.emails.append(value)
            case "URL": contact.urls.append(value)
            case "ADR": contact.address = value
            case "NOTE": contact.note = value
            default: break
            }
        }
        return contact == Contact() ? nil : contact
    }

    /// A vCard 2.1, 3.0 or 4.0. Folded lines are joined, groups (`item1.TEL`) and parameters
    /// (`TEL;TYPE=CELL`) are ignored.
    static func vCard(_ string: String) -> Contact? {
        var lines: [String] = []
        for line in string.split(whereSeparator: \.isNewline) {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else {
                lines.append(String(line))
            }
        }

        var contact = Contact()
        var structuredName: String?
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            var key = line[..<colon].uppercased()
            if let semicolon = key.firstIndex(of: ";") { key = String(key[..<semicolon]) }
            if let dot = key.lastIndex(of: ".") { key = String(key[key.index(after: dot)...]) }
            let rawValue = String(line[line.index(after: colon)...])
            let value = vCardUnescape(rawValue).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            switch key {
            case "FN":
                contact.name = value
            case "N":
                // Family;Given;Additional;Prefix;Suffix
                let parts = split(rawValue, on: ";").map { vCardUnescape($0).trimmingCharacters(in: .whitespaces) }
                let ordered = [3, 1, 2, 0, 4].compactMap { parts.indices.contains($0) ? parts[$0] : nil }
                let name = ordered.filter { !$0.isEmpty }.joined(separator: " ")
                if !name.isEmpty { structuredName = name }
            case "ORG":
                contact.organization = split(rawValue, on: ";").map(vCardUnescape).filter { !$0.isEmpty }.joined(separator: ", ")
            case "TITLE": contact.jobTitle = value
            case "TEL": contact.phoneNumbers.append(value.hasPrefix("tel:") ? String(value.dropFirst(4)) : value)
            case "EMAIL": contact.emails.append(value)
            case "URL": contact.urls.append(value)
            case "ADR":
                // PO box;Extended;Street;City;Region;Postal code;Country
                let parts = split(rawValue, on: ";").map { vCardUnescape($0).trimmingCharacters(in: .whitespaces) }
                let address = parts.filter { !$0.isEmpty }.joined(separator: ", ")
                if !address.isEmpty { contact.address = address }
            case "NOTE": contact.note = value
            default: break
            }
        }
        if contact.name == nil { contact.name = structuredName }
        return contact == Contact() ? nil : contact
    }

    // MARK: - Email, phone and SMS

    /// `mailto:hi@example.com?subject=Hello&body=Hi%20there`
    static func mailto(_ string: String) -> Email? {
        let rest = string.dropFirst("mailto:".count)
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let address = decode(String(parts.first ?? ""))
        let query = parts.count > 1 ? queryItems(String(parts[1])) : [:]
        let to = address.isEmpty ? (query["to"] ?? "") : address
        guard !to.isEmpty else { return nil }
        return Email(address: to, subject: query["subject"].nonEmpty, body: query["body"].nonEmpty)
    }

    /// `MATMSG:TO:hi@example.com;SUB:Hello;BODY:Hi there;;`
    static func matMsg(_ string: String) -> Email? {
        let values = fields(of: string.dropFirst("MATMSG:".count))
        guard let to = values["TO"], !to.isEmpty else { return nil }
        return Email(address: to, subject: values["SUB"].nonEmpty, body: values["BODY"].nonEmpty)
    }

    /// `sms:+15551234567?body=Hi`, `sms:+15551234567;?&body=Hi`, `SMSTO:+15551234567:Hi`
    static func sms(_ string: String) -> SMS? {
        let lowercased = string.lowercased()
        if lowercased.hasPrefix("smsto:") || lowercased.hasPrefix("mmsto:") {
            let parts = string.dropFirst(6).split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let number = String(parts.first ?? "").trimmingCharacters(in: .whitespaces)
            guard !number.isEmpty else { return nil }
            return SMS(number: number, body: parts.count > 1 ? String(parts[1]).nonEmpty : nil)
        }
        let rest = string.dropFirst("sms:".count)
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var number = decode(String(parts.first ?? ""))
        if let semicolon = number.firstIndex(of: ";") { number = String(number[..<semicolon]) }
        number = number.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return nil }
        let query = parts.count > 1 ? queryItems(String(parts[1])) : [:]
        return SMS(number: number, body: query["body"].nonEmpty)
    }

    /// Keeps digits, `+`, `*`, `#` and `,` so a number can go into a `tel:` URL.
    static func dialable(_ number: String) -> String {
        String(number.filter { $0.isNumber || "+*#,".contains($0) })
    }

    // MARK: - Location

    /// `geo:lat,lon[,alt][;crs=wgs84;u=35][?q=label]`
    static func geo(_ string: String) -> GeoLocation? {
        let rest = string.dropFirst("geo:".count)
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = (parts.first ?? "").split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let numbers = path.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count >= 2,
              let latitude = numbers[0], let longitude = numbers[1],
              (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { return nil }
        let altitude = numbers.count > 2 ? numbers[2] : nil
        let query = parts.count > 1 ? queryItems(String(parts[1]))["q"].nonEmpty : nil
        return GeoLocation(latitude: latitude, longitude: longitude, altitude: altitude, query: query)
    }

    // MARK: - URLs

    static func url(_ string: String) -> URL? {
        guard !string.isEmpty, !string.contains(where: \.isWhitespace) else { return nil }
        let lowercased = string.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            guard let url = URL(string: string), let host = url.host, !host.isEmpty else { return nil }
            return url
        }
        if lowercased.hasPrefix("www."), string.count > 4, string.dropFirst(4).contains(".") {
            return URL(string: "https://" + string)
        }
        // Any other scheme with an authority, for example `myapp://open` or `otpauth://totp/...`.
        if let range = string.range(of: "://") {
            let scheme = string[..<range.lowerBound]
            let isScheme = !scheme.isEmpty
                && scheme.first!.isLetter
                && scheme.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }
            if isScheme { return URL(string: string) }
        }
        return nil
    }

    static func isEmailAddress(_ string: String) -> Bool {
        guard !string.contains(where: \.isWhitespace) else { return false }
        let parts = string.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.lastIndex(of: "."), dot != domain.startIndex else { return false }
        return domain.index(after: dot) < domain.endIndex
    }

    // MARK: - Helpers

    /// Splits `KEY:value;KEY:value;;` into a dictionary with upper-cased keys and unescaped values.
    static func fields(of body: Substring) -> [String: String] {
        var result: [String: String] = [:]
        for field in split(body, on: ";") where !field.isEmpty {
            let pair = split(field, on: ":", maxSplits: 1)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespaces).uppercased()
            if result[key] == nil { result[key] = unescape(pair[1]) }
        }
        return result
    }

    /// Splits on `separator` except where it is escaped with a backslash. Escapes are kept so
    /// the parts can be split again; `unescape` removes them.
    static func split(_ text: some StringProtocol, on separator: Character, maxSplits: Int = .max) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaping = false
        for character in text {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                current.append(character)
                escaping = true
            } else if character == separator, parts.count < maxSplits {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
    }

    /// Removes backslash escapes: `\;` becomes `;`, `\\` becomes `\`.
    static func unescape(_ text: String) -> String {
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                result.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    /// vCard escapes: `\n` is a line break, `\,` `\;` `\\` are the characters themselves.
    static func vCardUnescape(_ text: String) -> String {
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    /// Drops one pair of surrounding double quotes, which some generators put around SSIDs.
    static func unquoted(_ text: String) -> String {
        guard text.count >= 2, text.first == "\"", text.last == "\"" else { return text }
        return String(text.dropFirst().dropLast())
    }

    static func decode(_ text: String) -> String {
        text.removingPercentEncoding ?? text
    }

    /// `a=1&b=two%20words` -> ["a": "1", "b": "two words"]. Keys are lower-cased, `+` is a space.
    static func queryItems(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for item in query.split(separator: "&") {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = pair.first, !name.isEmpty else { continue }
            let value = pair.count > 1 ? String(pair[1]).replacingOccurrences(of: "+", with: " ") : ""
            let key = decode(String(name)).lowercased()
            if result[key] == nil { result[key] = decode(value) }
        }
        return result
    }
}

extension Optional where Wrapped == String {
    /// `nil` for `nil` and for an empty string.
    var nonEmpty: String? {
        switch self {
        case .some(let value) where !value.isEmpty: value
        default: nil
        }
    }
}

extension String {
    /// `nil` for an empty string.
    var nonEmpty: String? { isEmpty ? nil : self }
}
