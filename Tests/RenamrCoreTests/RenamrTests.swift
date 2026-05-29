import XCTest
@testable import RenamrCore

final class RenamrTests: XCTestCase {

    /// Map every file through a single-example synthesis and return proposals.
    private func run(example: (String, String), files: [String]) -> [String] {
        Renamr.synthesize(examples: [example], files: files).previews.map(\.proposed)
    }

    // The headline demo: reformat date, reorder, drop tokens, title-case, keep counter.
    func testHeadlineDemo() {
        let result = Renamr.synthesize(
            examples: [("IMG_20240115_vacation_beach_DSC0931.jpg", "2024-01-15 Beach 0931.jpg")],
            files: [
                "IMG_20240115_vacation_beach_DSC0931.jpg",
                "IMG_20240116_trip_sunset_DSC0942.jpg",
                "IMG_20240117_party_night_DSC1003.jpg",
            ]
        )
        XCTAssertTrue(result.warnings.isEmpty, "should reproduce its own example: \(result.warnings)")
        XCTAssertEqual(result.previews.map(\.proposed), [
            "2024-01-15 Beach 0931.jpg",
            "2024-01-16 Sunset 0942.jpg",
            "2024-01-17 Night 1003.jpg",
        ])
        XCTAssertTrue(result.previews.allSatisfy(\.isConfident))
    }

    // Date reformat + separator-to-space, keeping a leading word verbatim.
    func testDateReformatAndSeparator() {
        let out = run(
            example: ("report_20231231", "report 2023-12-31"),
            files: ["report_20231231", "report_20240101", "report_20240630"]
        )
        XCTAssertEqual(out, ["report 2023-12-31", "report 2024-01-01", "report 2024-06-30"])
    }

    // Zero-pad a counter to a fixed width, leaving already-wide ones intact.
    func testCounterRepad() {
        let out = run(
            example: ("track1.mp3", "track01.mp3"),
            files: ["track1.mp3", "track2.mp3", "track10.mp3"]
        )
        XCTAssertEqual(out, ["track01.mp3", "track02.mp3", "track10.mp3"])
    }

    // Reorder fields and rewrite the separator (lastname, firstname).
    func testReorderWithLiteralSeparator() {
        let out = run(
            example: ("John_Smith", "Smith, John"),
            files: ["John_Smith", "Jane_Doe", "Ada_Lovelace"]
        )
        XCTAssertEqual(out, ["Smith, John", "Doe, Jane", "Lovelace, Ada"])
    }

    // A file that lacks the referenced fields is flagged, not silently mangled.
    func testUnresolvedFileIsFlagged() {
        let result = Renamr.synthesize(
            examples: [("IMG_20240115_beach.jpg", "2024-01-15 Beach.jpg")],
            files: ["IMG_20240115_beach.jpg", "totally_unrelated.txt"]
        )
        XCTAssertTrue(result.previews[0].isConfident)
        XCTAssertFalse(result.previews[1].isConfident, "a file with no date/second-word should not be claimed confident")
        // A flagged file shows its ORIGINAL name unchanged, never a half-built string.
        XCTAssertEqual(result.previews[1].proposed, "totally_unrelated.txt")
    }

    // Two number fields with coincidentally-equal values: one example is
    // ambiguous (was it the 1st or the 2nd number?), so Renamr should ask for a
    // second example on the file where the rival rules disagree — not guess.
    func testAmbiguityIsFlagged() {
        let result = Renamr.synthesize(
            examples: [("report_2023_2023.csv", "2023.csv")],
            files: ["report_2021_2099.csv", "report_2023_2023.csv", "report_1990_2050.csv"]
        )
        XCTAssertNotNil(result.needsMoreInfo, "ambiguous single example should request a second")
        XCTAssertEqual(result.needsMoreInfo?.options.count, 2)
    }

    // A second example collapses the ambiguity to a single rule.
    func testSecondExampleResolvesAmbiguity() {
        let result = Renamr.synthesize(
            examples: [("report_2023_2023.csv", "2023.csv"), ("report_2021_2099.csv", "2021.csv")],
            files: ["report_2021_2099.csv", "report_2023_2023.csv", "report_1990_2050.csv"]
        )
        XCTAssertNil(result.needsMoreInfo, "two examples should resolve the ambiguity")
        XCTAssertEqual(result.previews.map(\.proposed), ["2021.csv", "2023.csv", "1990.csv"])
    }

    // Lowercasing a name including its extension generalizes per-file: each file
    // keeps its OWN extension, just re-cased (.PNG -> .png), never forced to .jpg.
    func testExtensionCaseNormalization() {
        let out = run(
            example: ("PHOTO.JPG", "photo.jpg"),
            files: ["PHOTO.JPG", "SHOT.PNG", "clip.MP4"]
        )
        XCTAssertEqual(out, ["photo.jpg", "shot.png", "clip.mp4"])
    }

    // ---- Realistic filenames people actually have ----

    // macOS screenshots: keep the date, keep the "Screenshot" label, drop the time.
    func testRealScreenshots() {
        let out = run(
            example: ("Screenshot 2026-05-20 at 9.41.02 AM.png", "2026-05-20 Screenshot.png"),
            files: [
                "Screenshot 2026-05-20 at 9.41.02 AM.png",
                "Screenshot 2026-05-22 at 2.13.55 PM.png",
                "Screenshot 2026-05-29 at 7.18.42 PM.png",
            ]
        )
        XCTAssertEqual(out, ["2026-05-20 Screenshot.png", "2026-05-22 Screenshot.png", "2026-05-29 Screenshot.png"])
    }

    // Pixel/Android photos: pull the date out of the filename, drop the rest.
    func testRealPixelPhotos() {
        let out = run(
            example: ("PXL_20240115_103045.jpg", "2024-01-15.jpg"),
            files: ["PXL_20240115_103045.jpg", "PXL_20240220_080012.jpg", "PXL_20240305_171530.jpg"]
        )
        XCTAssertEqual(out, ["2024-01-15.jpg", "2024-02-20.jpg", "2024-03-05.jpg"])
    }

    // DSLR dump: strip the prefix, keep the counter, lowercase the extension.
    func testRealDslrStripAndLowercase() {
        let out = run(
            example: ("DSC0931.JPG", "0931.jpg"),
            files: ["DSC0931.JPG", "DSC0942.JPG", "DSC1003.JPG"]
        )
        XCTAssertEqual(out, ["0931.jpg", "0942.jpg", "1003.jpg"])
    }

    // iPhone dump: batch-label a trip, keep the counter, lowercase the extension.
    func testRealConstantLabelPlusCounter() {
        let out = run(
            example: ("IMG_4004.HEIC", "Trip 4004.heic"),
            files: ["IMG_4004.HEIC", "IMG_4005.HEIC", "IMG_4006.HEIC"]
        )
        XCTAssertEqual(out, ["Trip 4004.heic", "Trip 4005.heic", "Trip 4006.heic"])
    }

    // Abbreviation by prefix: January -> Jan generalizes to Feb, Mar, ...
    func testPrefixAbbreviation() {
        let out = run(
            example: ("January_2024.txt", "Jan 2024.txt"),
            files: ["January_2024.txt", "February_2024.txt", "March_2024.txt"]
        )
        XCTAssertEqual(out, ["Jan 2024.txt", "Feb 2024.txt", "Mar 2024.txt"])
    }

    // Variable-length tail: "Get Lucky" (2 words) must generalize to titles of
    // any length — "keep everything after the artist", not "keep two words".
    func testVariableLengthTitle() {
        let out = run(
            example: ("01 - Daft Punk - Get Lucky.mp3", "01 Get Lucky.mp3"),
            files: [
                "01 - Daft Punk - Get Lucky.mp3",
                "02 - Daft Punk - Instant Crush.mp3",
                "03 - Daft Punk - Doin it Right.mp3",
            ]
        )
        XCTAssertEqual(out, ["01 Get Lucky.mp3", "02 Instant Crush.mp3", "03 Doin it Right.mp3"])
    }

    // Tokenizer: a date is one token; an alpha-prefixed counter splits in two.
    func testTokenization() {
        let tokens = Tokenizer.tokenize("IMG_20240115_beach_DSC0931")
        XCTAssertEqual(tokens.filter { $0.kind == .date }.count, 1)
        XCTAssertEqual(tokens.filter { $0.kind == .word }.map(\.text), ["IMG", "beach", "DSC"])
        XCTAssertEqual(tokens.filter { $0.kind == .number }.map(\.text), ["0931"])
    }
}
