import Foundation

/// A video call service Kello recognizes, by the hosts its meeting links use.
public enum MeetingService: String, CaseIterable, Sendable {
    case zoom
    case googleMeet
    case teams
    case webex
    case faceTime
    case whereby
    case jitsi
    case chime
    case goTo

    /// The service's own name, shown in place of the link's host.
    public var name: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Teams"
        case .webex: "Webex"
        case .faceTime: "FaceTime"
        case .whereby: "Whereby"
        case .jitsi: "Jitsi Meet"
        case .chime: "Amazon Chime"
        case .goTo: "GoTo Meeting"
        }
    }

    /// Matched against the host itself or any subdomain of it.
    var hosts: [String] {
        switch self {
        case .zoom: ["zoom.us", "zoomgov.com"]
        case .googleMeet: ["meet.google.com"]
        case .teams: ["teams.microsoft.com", "teams.live.com", "teams.microsoft.us"]
        case .webex: ["webex.com"]
        case .faceTime: ["facetime.apple.com"]
        case .whereby: ["whereby.com"]
        case .jitsi: ["meet.jit.si"]
        case .chime: ["chime.aws"]
        case .goTo: ["gotomeeting.com", "meet.goto.com"]
        }
    }

    public init?(url: URL) {
        guard let host = url.host()?.lowercased(),
              let service = Self.allCases.first(where: { $0.hosts.contains { host == $0 || host.hasSuffix(".\($0)") } }) else { return nil }
        self = service
    }
}

/// Finds a video call link among an event's URL, location and notes.
public enum MeetingLink {
    /// Built once: creating a detector is far slower than running one, and every fetched
    /// event goes through here. Detectors are safe to share across threads.
    nonisolated(unsafe) private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// The first call link in `texts`, searched in order. Links wrapped by Outlook's Safe
    /// Links are unwrapped first, so a Teams call hidden behind one is still found.
    public static func find(in texts: [String?]) -> URL? {
        guard let detector else { return nil }
        for text in texts.compactMap({ $0 }) where mayContainLink(text) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url.map(unwrapped) else { continue }
                if MeetingService(url: url) != nil { return url }
            }
        }
        return nil
    }

    /// The link a Safe Links (`*.safelinks.protection.outlook.com/?url=...`) URL points to,
    /// or the URL itself.
    public static func unwrapped(_ url: URL) -> URL {
        guard let host = url.host()?.lowercased(), host.hasSuffix("safelinks.protection.outlook.com"),
              let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "url" })?.value,
              let inner = URL(string: target), inner.host() != nil else { return url }
        return inner
    }

    /// A cheap check that skips the detector for text that can't hold a call link, which
    /// is most locations and notes.
    private static func mayContainLink(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("safelinks") || MeetingService.allCases.contains { $0.hosts.contains { lowered.contains($0) } }
    }
}

extension CalendarEvent {
    /// The service the call link belongs to.
    public var meetingService: MeetingService? {
        meetingURL.flatMap(MeetingService.init(url:))
    }
}
