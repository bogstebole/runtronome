import Foundation
import CryptoKit

// MARK: - Garmin Connect authentication (unofficial)
//
// Garmin has no official API for reading a user's *planned* workouts, so this
// follows the same flow the Connect mobile app (and the garth/python-
// garminconnect libraries) use: SSO login with the user's own credentials →
// service ticket → OAuth1 preauthorized token → OAuth2 bearer for
// connectapi.garmin.com. Tokens live in the Keychain; the OAuth1 token is
// long-lived (~1 year) and silently re-mints expired OAuth2 bearers.
//
// Endpoints are unofficial and may change — every parse failure surfaces as a
// readable error rather than a crash.

enum GarminAuthError: LocalizedError {
    case badCredentials
    case network(String)
    case parse(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .badCredentials: return "Garmin didn't accept that email/password."
        case .network(let m): return m
        case .parse(let m):   return "Garmin changed something — \(m)"
        case .notLoggedIn:    return "Sign in to Garmin first."
        }
    }
}

// MARK: Tokens

struct GarminOAuth1Token: Codable {
    let token: String
    let secret: String
    var mfaToken: String?
}

struct GarminOAuth2Token: Codable {
    let accessToken: String
    let expiresAt: Date

    var isExpired: Bool { Date() > expiresAt.addingTimeInterval(-120) }
}

// MARK: - Session (token storage + refresh)

enum GarminSession {
    private static let oauth1Key = "garmin.oauth1"
    private static let oauth2Key = "garmin.oauth2"

    static var isLoggedIn: Bool { oauth1() != nil }

    static func oauth1() -> GarminOAuth1Token? {
        Keychain.load(oauth1Key).flatMap { try? JSONDecoder().decode(GarminOAuth1Token.self, from: $0) }
    }

    private static func oauth2() -> GarminOAuth2Token? {
        Keychain.load(oauth2Key).flatMap { try? JSONDecoder().decode(GarminOAuth2Token.self, from: $0) }
    }

    static func store(oauth1: GarminOAuth1Token) {
        if let data = try? JSONEncoder().encode(oauth1) { Keychain.save(data, key: oauth1Key) }
    }

    static func store(oauth2: GarminOAuth2Token) {
        if let data = try? JSONEncoder().encode(oauth2) { Keychain.save(data, key: oauth2Key) }
    }

    static func logout() {
        Keychain.delete(oauth1Key)
        Keychain.delete(oauth2Key)
    }

    /// A live bearer token — re-minted from the long-lived OAuth1 token when
    /// the cached one is missing or expired.
    static func validAccessToken() async throws -> String {
        if let cached = oauth2(), !cached.isExpired { return cached.accessToken }
        guard let oauth1 = oauth1() else { throw GarminAuthError.notLoggedIn }
        let fresh = try await GarminLogin.exchange(oauth1: oauth1)
        store(oauth2: fresh)
        return fresh.accessToken
    }
}

// MARK: - Login flow

/// Result of the first credentials step: either done, or Garmin wants an MFA
/// code — the context carries the cookies/CSRF needed to finish.
enum GarminLoginResult {
    case success
    case mfaRequired(GarminMFAContext)
}

struct GarminMFAContext {
    let csrf: String
    let session: URLSession
}

enum GarminLogin {
    private static let sso = "https://sso.garmin.com/sso"
    private static let api = "https://connectapi.garmin.com"
    private static let userAgent = "com.garmin.android.apps.connectmobile"

    // The Connect mobile app's OAuth1 consumer pair (public knowledge; the
    // garth project redistributes it). Fetched fresh at login with this as
    // the fallback in case the bucket is unreachable.
    private static let fallbackConsumer = ("fc3e99d2-118c-44b8-8ae3-03370dde24c0",
                                           "E08WAR897WEy2knn7aFBrvegVAf0AFdWBBF")

    private static var ssoParams: [URLQueryItem] {
        [
            URLQueryItem(name: "id", value: "gauth-widget"),
            URLQueryItem(name: "embedWidget", value: "true"),
            URLQueryItem(name: "gauthHost", value: "\(sso)/embed"),
            URLQueryItem(name: "service", value: "\(sso)/embed"),
            URLQueryItem(name: "source", value: "\(sso)/embed"),
            URLQueryItem(name: "redirectAfterAccountLoginUrl", value: "\(sso)/embed"),
            URLQueryItem(name: "redirectAfterAccountCreationUrl", value: "\(sso)/embed")
        ]
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: config)
    }

    // MARK: Step 1 — credentials

    static func login(email: String, password: String) async throws -> GarminLoginResult {
        let session = makeSession()

        // Prime cookies, then pull the CSRF token off the sign-in form.
        var embed = URLComponents(string: "\(sso)/embed")!
        embed.queryItems = [
            URLQueryItem(name: "id", value: "gauth-widget"),
            URLQueryItem(name: "embedWidget", value: "true"),
            URLQueryItem(name: "gauthHost", value: sso)
        ]
        _ = try? await session.data(from: embed.url!)

        var signin = URLComponents(string: "\(sso)/signin")!
        signin.queryItems = ssoParams
        let (pageData, _) = try await get(session, signin.url!)
        guard let csrf = firstMatch(#"name="_csrf"\s+value="([^"]+)""#, in: pageData) else {
            throw GarminAuthError.parse("couldn't find the sign-in form token.")
        }

        // Submit credentials.
        var request = URLRequest(url: signin.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(signin.url!.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = formBody([
            "username": email, "password": password, "embed": "true", "_csrf": csrf
        ])
        let (data, response) = try await session.data(for: request)

        // Success is signalled by a service ticket in the response — check for
        // it FIRST. The page mentions "MFA" (a set-up link) even when 2FA is
        // off, so keying MFA on that string wrongly hijacks a good login.
        if let ticket = extractTicket(from: data) {
            try await completeLogin(ticket: ticket, session: session)
            return .success
        }

        // No ticket: only a real 2FA challenge redirects to the verify page or
        // renders an MFA-code field. Anything else is bad credentials.
        let onMFAPage = (response.url?.absoluteString.contains("verifyMFA") ?? false)
            || contains(#"(mfa-code|verifyMFA|loginEnterMfaCode)"#, in: data)
        if onMFAPage {
            guard let mfaCsrf = firstMatch(#"name="_csrf"\s+value="([^"]+)""#, in: data) else {
                throw GarminAuthError.parse("couldn't find the MFA form token.")
            }
            return .mfaRequired(GarminMFAContext(csrf: mfaCsrf, session: session))
        }

        throw GarminAuthError.badCredentials
    }

    /// The service ticket appears in a redirect URL in the response body.
    /// Garmin has shipped a couple of shapes over the years, so try both.
    private static func extractTicket(from data: Data) -> String? {
        firstMatch(#"embed\?ticket=([^"'&]+)"#, in: data)
            ?? firstMatch(#"ticket=([A-Za-z0-9-]+-cas)"#, in: data)
    }

    // MARK: Step 2 — MFA code (only when Garmin asks)

    static func submitMFA(code: String, context: GarminMFAContext) async throws {
        var url = URLComponents(string: "\(sso)/verifyMFA/loginEnterMfaCode")!
        url.queryItems = ssoParams
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(url.url!.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = formBody([
            "mfa-code": code, "embed": "true", "_csrf": context.csrf, "fromPage": "setupEnterMfaCode"
        ])
        let (data, _) = try await context.session.data(for: request)
        guard let ticket = extractTicket(from: data) else {
            throw GarminAuthError.badCredentials
        }
        try await completeLogin(ticket: ticket, session: context.session)
    }

    // MARK: Ticket → OAuth1 → OAuth2

    private static func completeLogin(ticket: String, session: URLSession) async throws {
        let consumer = await fetchConsumer()

        var preauth = URLComponents(string: "\(api)/oauth-service/oauth/preauthorized")!
        preauth.queryItems = [
            URLQueryItem(name: "ticket", value: ticket),
            URLQueryItem(name: "login-url", value: "\(sso)/embed"),
            URLQueryItem(name: "accepts-mfa-tokens", value: "true")
        ]
        var request = URLRequest(url: preauth.url!)
        request.setValue(OAuth1.header(for: request, consumer: consumer, token: nil),
                         forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        guard let body = String(data: data, encoding: .utf8) else {
            throw GarminAuthError.parse("empty token response.")
        }
        let fields = parseQuery(body)
        guard let token = fields["oauth_token"], let secret = fields["oauth_token_secret"] else {
            throw GarminAuthError.parse("no OAuth token in the response.")
        }
        let oauth1 = GarminOAuth1Token(token: token, secret: secret, mfaToken: fields["mfa_token"])
        GarminSession.store(oauth1: oauth1)
        GarminSession.store(oauth2: try await exchange(oauth1: oauth1, session: session, consumer: consumer))
    }

    /// Mint an OAuth2 bearer from the long-lived OAuth1 token.
    static func exchange(
        oauth1: GarminOAuth1Token,
        session sessionOverride: URLSession? = nil,
        consumer consumerOverride: (String, String)? = nil
    ) async throws -> GarminOAuth2Token {
        let session = sessionOverride ?? makeSession()
        let consumer: (String, String)
        if let consumerOverride {
            consumer = consumerOverride
        } else {
            consumer = await fetchConsumer()
        }

        let url = URL(string: "\(api)/oauth-service/oauth/exchange/user/2.0")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var extraParams: [String: String] = [:]
        if let mfa = oauth1.mfaToken { extraParams["mfa_token"] = mfa }
        request.httpBody = formBody(extraParams)
        request.setValue(
            OAuth1.header(for: request, consumer: consumer,
                          token: (oauth1.token, oauth1.secret), bodyParams: extraParams),
            forHTTPHeaderField: "Authorization"
        )
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GarminAuthError.network("Garmin refused the token exchange — try signing in again.")
        }
        struct Exchange: Codable { let access_token: String; let expires_in: Double }
        guard let decoded = try? JSONDecoder().decode(Exchange.self, from: data) else {
            throw GarminAuthError.parse("unreadable token exchange response.")
        }
        return GarminOAuth2Token(
            accessToken: decoded.access_token,
            expiresAt: Date().addingTimeInterval(decoded.expires_in)
        )
    }

    private static func fetchConsumer() async -> (String, String) {
        struct Consumer: Codable { let consumer_key: String; let consumer_secret: String }
        guard let url = URL(string: "https://thegarth.s3.amazonaws.com/oauth_consumer.json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(Consumer.self, from: data)
        else { return fallbackConsumer }
        return (decoded.consumer_key, decoded.consumer_secret)
    }

    // MARK: Helpers

    private static func get(_ session: URLSession, _ url: URL) async throws -> (Data, URLResponse) {
        do { return try await session.data(from: url) }
        catch { throw GarminAuthError.network("Couldn't reach Garmin — check your connection.") }
    }

    private static func contains(_ pattern: String, in data: Data) -> Bool {
        guard let html = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: pattern)
        else { return false }
        return regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) != nil
    }

    private static func firstMatch(_ pattern: String, in data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range])
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        fields.map { "\(OAuth1.encode($0.key))=\(OAuth1.encode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }

    private static func parseQuery(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            }
        }
        return result
    }
}

// MARK: - Minimal OAuth1 signer (HMAC-SHA1)

enum OAuth1 {
    /// RFC 5849 Authorization header for the given request. `bodyParams` must
    /// include any form fields (they're part of the signature base).
    static func header(
        for request: URLRequest,
        consumer: (key: String, secret: String),
        token: (token: String, secret: String)?,
        bodyParams: [String: String] = [:]
    ) -> String {
        var oauthParams: [String: String] = [
            "oauth_consumer_key": consumer.key,
            "oauth_nonce": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "oauth_signature_method": "HMAC-SHA1",
            "oauth_timestamp": String(Int(Date().timeIntervalSince1970)),
            "oauth_version": "1.0"
        ]
        if let token { oauthParams["oauth_token"] = token.token }

        let url = request.url!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let queryParams = (components.queryItems ?? []).reduce(into: [String: String]()) {
            $0[$1.name] = $1.value ?? ""
        }
        components.query = nil
        let baseURL = components.url!.absoluteString

        let allParams = queryParams
            .merging(oauthParams) { a, _ in a }
            .merging(bodyParams) { a, _ in a }
        var encodedPairs: [(String, String)] = []
        for (key, value) in allParams {
            encodedPairs.append((encode(key), encode(value)))
        }
        encodedPairs.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        let paramString = encodedPairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")

        let base = [request.httpMethod ?? "GET", encode(baseURL), encode(paramString)]
            .joined(separator: "&")
        let signingKey = "\(encode(consumer.secret))&\(encode(token?.secret ?? ""))"
        let signature = Data(HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(base.utf8),
            using: SymmetricKey(data: Data(signingKey.utf8))
        )).base64EncodedString()

        oauthParams["oauth_signature"] = signature
        let header = oauthParams
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(encode($0.value))\"" }
            .joined(separator: ", ")
        return "OAuth \(header)"
    }

    /// RFC 3986 percent-encoding (stricter than `.urlQueryAllowed`).
    static func encode(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

// MARK: - Keychain (one generic-password item per key)

enum Keychain {
    static func save(_ data: Data, key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
