//
//  MathLatexParserTests.swift
//
//
//  Created by Peter Tang on 9/10/2023.
//

import XCTest
@testable import MathLatex
@testable import Parsing

final class MathLatexParserTests: XCTestCase {
    func testTrimsAllWhitespace() {
      let parser = Parse(input: Substring.self) {
        Whitespace()
      }
      var input = "    \r \t\t \r\n \n\r    Hello, world!"[...]
      XCTAssertNotNil(try parser.parse(&input))
      XCTAssertEqual("Hello, world!", input)
    }
}
