import XCTest
@testable import NandoWordSearch

final class WordGenerationValidatorTests: XCTestCase {
    func testValidateWordsRecoversTenWordsFromSingleCombinedString() throws {
        let recoveredWords = try WordGenerationValidator.validateWords([
            "ALPHA, BRAVO, CHARL, DELTA, EAGLE, FJORD, GHOST, HOTEL, INDIA, JOKER",
        ])

        XCTAssertEqual(recoveredWords.count, 10)
        XCTAssertEqual(recoveredWords.first, "ALPHA")
        XCTAssertEqual(recoveredWords.last, "JOKER")
    }

    func testValidateWordsRecoversTenWordsFromNewlineSeparatedSingleString() throws {
        let recoveredWords = try WordGenerationValidator.validateWords([
            """
            ALPHA
            BRAVO
            CHARL
            DELTA
            EAGLE
            FJORD
            GHOST
            HOTEL
            INDIA
            JOKER
            """,
        ])

        XCTAssertEqual(recoveredWords.count, 10)
        XCTAssertEqual(recoveredWords[3], "DELTA")
    }

    func testParseAndValidateLooseWordsRecoversFromPlainTextList() throws {
        let recoveredWords = try WordGenerationValidator.parseAndValidateLooseWords(from: """
        ALPHA, BRAVO, CHARL, DELTA, EAGLE, FJORD, GHOST, HOTEL, INDIA, JOKER
        """)

        XCTAssertEqual(recoveredWords.count, 10)
        XCTAssertEqual(recoveredWords[5], "FJORD")
    }
}
