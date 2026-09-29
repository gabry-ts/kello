import XCTest
@testable import KelloCore

final class MeetingLinkTests: XCTestCase {
    func testFindsLinksInTheURLLocationAndNotes() {
        XCTAssertEqual(MeetingLink.find(in: ["https://us02web.zoom.us/j/123?pwd=x", nil, nil])?.host(), "us02web.zoom.us")
        XCTAssertEqual(MeetingLink.find(in: [nil, "https://meet.google.com/abc-defg-hij", nil])?.absoluteString,
                       "https://meet.google.com/abc-defg-hij")
        let notes = "Agenda attached.\nJoin: <https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=x>"
        XCTAssertEqual(MeetingLink.find(in: [nil, "Room 4", notes])?.host(), "teams.microsoft.com")
    }

    func testTheURLFieldWinsOverTheNotes() {
        let found = MeetingLink.find(in: ["https://acme.webex.com/meet/ada", nil, "Backup: https://meet.google.com/xyz-abcd-efg"])
        XCTAssertEqual(found?.host(), "acme.webex.com")
    }

    func testUnwrapsSafeLinks() {
        let target = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0"
        let encoded = target.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let wrapped = "https://eur03.safelinks.protection.outlook.com/?url=\(encoded)&data=05%7C01&reserved=0"
        let found = MeetingLink.find(in: [nil, nil, "Click here to join the meeting<\(wrapped)>"])
        XCTAssertEqual(found?.absoluteString, target)
        XCTAssertEqual(found.flatMap(MeetingService.init(url:)), .teams)
        // A Safe Link to anything else is not a call.
        let other = "https://eur03.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com%2F&data=1"
        XCTAssertNil(MeetingLink.find(in: [other]))
    }

    func testIgnoresLookalikes() {
        XCTAssertNil(MeetingLink.find(in: ["https://example.com/zoom.us", "Room 4", "notzoom.us.example.org"]))
        XCTAssertNil(MeetingLink.find(in: [nil, "", "Call me on zoom"]))
    }

    func testServiceNames() {
        func name(_ link: String) -> String? { URL(string: link).flatMap(MeetingService.init(url:))?.name }
        XCTAssertEqual(name("https://us02web.zoom.us/j/1"), "Zoom")
        XCTAssertEqual(name("https://meet.google.com/abc"), "Google Meet")
        XCTAssertEqual(name("https://teams.live.com/meet/1"), "Teams")
        XCTAssertEqual(name("https://acme.webex.com/meet/ada"), "Webex")
        XCTAssertNil(name("https://example.com"))
    }
}
