//
//  RegExTests.swift
//  
//
//  Created by Peter Tang on 7/10/2023.
//

import XCTest
import Foundation

final class RegExTests: XCTestCase {
    func testSimpleRegExMathBlockScript3() {
        let testPattern = [
            #"(?<![`\$])\$`.+?`\$(?![`\$])"#, // Starts with $ & backtick, non-greedy, ends with backtick and $, with no line breaks,
        ].joined(separator: "|")
        let inputString = #"""
        A line to confuse start of line check.
        $$
         block not to be detected
        $$
            - $`(a_1 + a_2)^2 =  a_1^2 + 2a_1a_2 +  a_2^2`$
            - $ when one dollar sign $ -
            - $$ when two dollar signs $$ -
            - $$$ when three dollar signs $$$ -
        A line to confuse end of line checks.
        """#
        guard let regEx = try? NSRegularExpression(pattern: testPattern) else {
            fatalError("RegEx invalid: \(testPattern)")
        }
        let result = helperEnumerate(inputString: inputString, regEx)
        // for (idx, ss) in result.sString.enumerated() {
        //     print("\(idx):\(ss):\(idx)")
        // }
        XCTAssert(result.count == 1, "\(result) using \(testPattern)")
    }
    func testSimpleRegExMathBlockScript2() {
        let testPattern = [
            #"(?<![`\$])\$(?![`\$])(.+?)(?<![`\$])\$(?![`\$])"#,// Starts with $, non-greedy, ends with $, look-ahead and look-behind
        ].joined(separator: "|")
        let inputString = #"""
        A line to confuse start of line check.
        $$
         block not to be detected
        $$
            - $`(a_1 + a_2)^2 =  a_1^2 + 2a_1a_2 +  a_2^2`$
            - $\log_b(x) = \frac{\log_a(x)}{\log_a(b)}$
            - $ when one dollar sign is detected $ -
            - $$ when two dollar signs are detected $$ -
            - $$$ when three dollar signs are detected $$$ -
        A line to confuse end of line checks.
        """#
        guard let regEx = try? NSRegularExpression(pattern: testPattern) else {
            fatalError("RegEx invalid: \(testPattern)")
        }
        let result = helperEnumerate(inputString: inputString, regEx)
        // for (idx, ss) in result.sString.enumerated() {
        //     print("\(idx):\(ss):\(idx)")
        // }
        XCTAssert(result.count == 2, "\(result) using \(testPattern)")
    }

    func testSimpleRegExMathBlockScript1() {
        let testPattern = [
            #"(?sm:^\$\$$.*?^\$\$$)"#,
        ].joined(separator: "|")
        let inputString = #"""
        A line to confuse start of line check.
        $$
           First block to detect
        $$
         $$
            should not be detected
         $$
            - $ should never be included $ -
            - $$ should never be included $$ -
            - $$$ should never be included $$$ -
        $$
           Second block to detect
        $$
        A line to confuse end of line checks.
        """#
        guard let regEx = try? NSRegularExpression(pattern: testPattern) else { return }

        let result = helperEnumerate(inputString: inputString, regEx)
        // for (idx, ss) in result.sString.enumerated() {
        //     print("\(idx):\(ss):\(idx)")
        // }
        XCTAssert(result.count == 2, "\(result)")
    }
    func helperEnumerate(inputString: String, _ regEx: NSRegularExpression) -> (count: Int, sString: [Substring]) {
        let fullNSRange = inputString.fullNSRange
        var extract = [Substring]()
        var found = 0
        regEx.enumerateMatches(in: inputString, range: fullNSRange) { result, flag, _ in
            guard let _ = result, let range: NSRange = result?.range,
                  range.lowerBound != NSNotFound, range.upperBound != NSNotFound,
                  let stringRange = Range(range, in: inputString) else { return }
            found += 1
            extract.append(inputString[stringRange])
        }
        return (found, extract)
    }
}
private extension RangeExpression where Bound == String.Index  {
    func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}
private extension String {
    var fullRange: Range<String.Index> {
        startIndex ..< endIndex
    }
    var fullNSRange: NSRange {
        fullRange.nsRange(in: self)
    }
}
