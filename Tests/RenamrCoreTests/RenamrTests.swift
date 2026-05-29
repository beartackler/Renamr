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

    // Tokenizer: a date is one token; an alpha-prefixed counter splits in two.
    func testTokenization() {
        let tokens = Tokenizer.tokenize("IMG_20240115_beach_DSC0931")
        XCTAssertEqual(tokens.filter { $0.kind == .date }.count, 1)
        XCTAssertEqual(tokens.filter { $0.kind == .word }.map(\.text), ["IMG", "beach", "DSC"])
        XCTAssertEqual(tokens.filter { $0.kind == .number }.map(\.text), ["0931"])
    }
}
