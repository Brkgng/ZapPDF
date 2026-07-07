//
//  SupportLink.swift
//  ZapPDF
//
//  Builds a direct email support link with a prefilled subject for ZapPDF.
//

import Foundation

/// Builds a `mailto:` support URL with a prefilled subject for ZapPDF.
///
/// A direct email path lets paying users attach problematic PDFs and continue
/// a threaded conversation, which a web feedback form cannot reliably support.
enum SupportLink {
    /// The support email address for ZapPDF.
    static let supportEmailAddress = "yasarberkergungor@gmail.com"

    /// Builds a `mailto:` URL whose subject includes the app name and public version.
    ///
    /// - Parameters:
    ///   - appName: The display name of the app (e.g. "ZapPDF").
    ///   - appVersion: The version string, optionally with build (e.g. "1.2.3 (1)").
    /// - Returns: A `mailto:` URL, or `nil` if the components cannot be encoded.
    static func mailtoURL(appName: String, appVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject(appName: appName, appVersion: appVersion))
        ]
        return components.url
    }

    /// Formats the prefilled support subject line.
    ///
    /// When `appVersion` is non-empty the subject becomes `"<appName> Support (v<version>)"`,
    /// with any trailing numeric build suffix omitted.
    /// otherwise it falls back to `"<appName> Support"`.
    static func subject(appName: String, appVersion: String) -> String {
        let publicVersion = publicVersion(from: appVersion)
        if publicVersion.isEmpty {
            return "\(appName) Support"
        }
        return "\(appName) Support (v\(publicVersion))"
    }

    private static func publicVersion(from appVersion: String) -> String {
        let trimmedVersion = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedVersion.hasSuffix(")") else {
            return trimmedVersion
        }
        guard let buildPrefixRange = trimmedVersion.range(of: " (", options: .backwards) else {
            return trimmedVersion
        }

        let buildStart = buildPrefixRange.upperBound
        let buildEnd = trimmedVersion.index(before: trimmedVersion.endIndex)
        let build = trimmedVersion[buildStart..<buildEnd]
        guard !build.isEmpty, build.allSatisfy(\.isNumber) else {
            return trimmedVersion
        }

        return String(trimmedVersion[..<buildPrefixRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
