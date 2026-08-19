import SwiftUI

// MARK: - About screen

/// A full-screen "About" overlay shown when the backspace key is tapped three
/// times while the display is "0". Styled to match the calculator's muted,
/// earthy palette (see `Color` extension in `ContentView.swift`).
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        if !GitInfo.commitHash.isEmpty, GitInfo.commitHash != "0000000" {
            return "\(version) (\(GitInfo.commitHash))"
        }
        return version
    }
      // MARK: - Provisioning profile expiry

      // The "Expires N days" line, styled like the version line. Edge cases:
      //   * expired profile (≤ 0 days)  → "Expires 0 days"
      //   * one day left                → "Expires 1 days"
      //   * profile absent / unreadable  → "Expires Unknown"
    private var provisioningExpiryString: String {
        guard let days = daysUntilProvisioningExpiry() else {
            return "Expires Unknown"
         }
        return "Expires \(days) days"
     }

      // Whole days remaining until the profile's ExpirationDate. Floors to whole
      // days and clamps expired profiles to 0. Returns nil when the profile is
      // missing or unparseable (e.g. an unsigned simulator build).
    private func daysUntilProvisioningExpiry() -> Int? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return nil
         }
        let data: Data
        do {
            data = try Data(contentsOf: url)
         } catch {
            return nil
         }
        guard let expiry = Self.parseExpirationDate(from: data) else {
            return nil
         }
        let days = Int((expiry.timeIntervalSinceNow / 86_400).rounded(.down))
        return max(0, days)
     }

      // `embedded.mobileprovision` is a PKCS#7-wrapped XML plist, so the
       // ExpirationDate value (e.g. "2026-08-17T12:34:56Z") appears verbatim in
       // the raw bytes: locate the `ExpirationDate` key, then the following
       // `<date>…</date>` element, and parse the UTC timestamp.

    private static func parseExpirationDate(from data: Data) -> Date? {
        let xml = String(decoding: data, as: UTF8.self)
        guard let keyRange = xml.range(of: "ExpirationDate") else { return nil }
        let tail = String(xml[keyRange.upperBound...])
        guard let openRange = tail.range(of: "<date>") else { return nil }
        let afterOpen = String(tail[openRange.upperBound...])
        guard let closeRange = afterOpen.range(of: "</date>") else { return nil }
        var iso = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
             .trimmingCharacters(in: .whitespacesAndNewlines)
        // The value is UTC ISO8601 (e.g. "2026-08-17T12:34:56Z"); drop the
        // trailing "Z" so the formatter can parse the wall-clock fields.
        if iso.hasSuffix("Z") { iso.removeLast() }
        return expiryFormatter.date(from: iso)
      }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
      }()

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title block.
                VStack(spacing: 8) {
                    Text("Calculator")
                        .font(.system(size: 44, weight: .light, design: .rounded).monospacedDigit())
                        .foregroundColor(.warmInk)

                    Text("Version \(versionString)")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.mutedInk)

                    // Days until the provisioning profile expires, read from the
                    // embedded.mobileprovision shipped in signed builds.
                    Text(provisioningExpiryString)
                          .font(.system(size: 17, weight: .regular).monospacedDigit())
                          .foregroundColor(.mutedInk)
                 }
                 .padding(.bottom, 48)

                // A short blurb.
                Text(
                    "A clean, distraction-free calculator with a two-line "
                        + "display and a muted, earthy palette."
                )
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.mutedInk.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 280)
                .padding(.bottom, 48)

                // Dismiss button, styled like a top-row (lavender) button.
                Text("Done")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.darkInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.topBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture { dismiss() }
            }
            .padding(24)

            Spacer()
        }
    }
}

#Preview {
    AboutView()
}
