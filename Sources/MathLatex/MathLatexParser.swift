//
//  MathLatexParser.swift
//
//
//  Created by Peter Tang on 6/10/2023.
//

// https://itnext.io/writing-a-mathematical-expression-parser-35b0b78f869e

import Foundation
import Parsing

/// https://github.com/bradhowes/swift-math-parser.git
/// https://github.com/petersktang/latex2unicode.git

// expr = term ((PLUS | MINUS) term)*
// term = factor ((CDOT factor | primary )* // primary and factor must both not be NUMBERs
// factor = MINUS? power
// power = primary (CARET primary)*
// primary = grouping
//         | environnment
//         | frac
//         | function
//         | NUMBER
//         | VARIABLE
// grouping = LEFT LPAREN expr RIGHT RPAREN
//          | LPAREN expr RPAREN
//          | LBRACE expr RBRACE
//          | LEFT BAR expr RIGHT BAR
//          | BAR expr BAR
// environnment = matrix
// frac = FRAC LBRACE expr RBRACE LBRACE expr RBRACE
// function = (SQRT | SIN | COS | TAN ...) grouping
// matrix = BEGIN LBRACE MATRIX RBRACE ((expr)(AMP | DBLBACKSLASH))* END LBRACE MATRIX RBRACE

// https://itnext.io/writing-a-mathematical-expression-parser-35b0b78f869e
// EXPRESSION
//     : ADDITION
//     ;
//
// ADDITION
//     : ADDITION ('+' | '-') CALL
//     | CALL
//     ;
//
// CALL
//     : MULTIPLICATION
//     | identifier CALL
//     | identifier '(' EXPRESSION [',' EXPRESSION]* ')'
//     ;
//
// MULTIPLICATION
//     : MULTIPLICATION ('*' | '/') EXPONENTIATION
//     | EXPONENTIATION
//     ;
//
// EXPONENTIATION
//     : EXPONENTIATION '^' BASIC
//     | BASIC
//     ;
//
// BASIC
//     : number
//     | identifier
//     | string
//     | '(' EXPRESSION ')'
//     ;
// let tokens = [
//     [/^\s+/, null],
//     [/^-?\d+(?:\.\d+)?/, 'NUMBER'],
//     [/^[a-zA-Z]+/, 'IDENT'],
//     [/^"[^"]+"/, 'STRING'],
//     [/^\+/, '+'],
//     [/^-/, '-'],
//     [/^\*/, '*'],
//     [/^\^/, '^'],
//     [/^\//, '/'],
//     [/^\(/, '('],
//     [/^\)/, ')'],
//     [/^,/, ','],
// ]

// https://www.robertjacobson.dev/the-grammar-of-mathematical-expressions
// term
//     :    INT
//     |    ID
//     |    '(' expr ')' //parentheses
//     ;
//
// //Implicit multiplication
// factor
//     :    term
//     |    <assoc=right> term '^' factor
//     |    term factor
//     ;
//
// //Unary minus/plus
// prefix
//     :    factor
//     |    ('+' | '-') prefix //unary plus/minus
//     ;
//
// //Explicit multiplication/division
// multdiv
//     :    prefix
//     |    multdiv '/' prefix //division
//     |    multdiv '*' prefix //explicit multiplication
//     ;
//
// expr
//     :    multdiv
//     |    expr ('+' | '-') multdiv //addition/subtraction
//     ;
// term
//     :    LEAF
//     |    '(' expr ')'    //parentheses
//     ;
//
// //Implicit multiplication
// factor
//     :    term
//     |    <assoc=right> term '^' factor
//     |    term factor
//     ;
//
// //Unary minus/plus
// expr
//     :    factor
//     |    ('+' | '-') expr //unary plus/minus
//     |    expr '/' expr    //division
//     |    expr '*' expr    //explicit multiplication
//     |    expr ('+' | '-') expr    //addition/subtraction
//     ;

public enum MathLatex {
    enum Parsers {}
    enum Syntax {}

}
extension MathLatex.Syntax {
    // Use within begin{equation} ...end{equation}
    enum MatrixEnvironment: String, CaseIterable {
        case pmatrix, bmatrix, Bmatrix, vmatrix, Vmatrix
    }
    enum Environment: String, CaseIterable {
        case matrix, eqalign, split, aligned, displaylines, gather, eqnarray, cases
        // displaymath, array, equation, equation*, multline, flalign*, theorem, alignat
    }
    enum Command: String, CaseIterable {
        case textbf, texttt
        case atop, choose, brace, brack
    }
    // overall file: text, formula, command
    enum Formula {
        
    }

}
extension MathLatex.Parsers {
    static var sample: any Parser {
        Parse(input: Substring.self) {
            Int.parser()
            Bool.parser()
        }.eraseToAnyParser()
    }
    func parenParser() -> AnyParser<Substring, Substring> {
        Parse {
            "("
            Many(into: Substring("")) { string, fragment in
                string += fragment
            } element: {
                OneOf {
                    Prefix(1...) { $0 != "(" && $0 != ")" }

                    Lazy { parenParser() }
                }
            } terminator: {
                ")"
            }
        }
        .eraseToAnyParser()
    }
    static let operatorSymbol = CharacterSet(charactersIn: #"+=*/()[]"#)
    static let punctuationMark = CharacterSet(charactersIn: ",;.?!:-'\t\n")
    static let specialKeys = CharacterSet(charactersIn: #"#$%&~_^\{}@"|"#)
    static let alphabets = ["a" ... "Z"][...]
    static var environment: any Parser {
        Parse(input: Substring.self) {
            "\\begin{"; MathLatex.Syntax.Environment.parser(); "}"
   
            "\\end{"; MathLatex.Syntax.Environment.parser(); "}"
        }
    }
    static var command: any Parser {
        Parse(input: Substring.self) {
            MathLatex.Syntax.Command.parser()
            Parsing.Whitespace(1, .horizontal)
            // until hitting any character other than a-z, A-Z
            Prefix(1...) { !("a" ... "Z").contains($0) }
        }
    }
    static var frac: any Parser {
        Parse(input: Substring.self) {
            "\\frac{"
            // norminator
            "}{"
            // denorminator
            "}"
        }
    }
    static var sqrt: any Parser {
        Parse(input: Substring.self) {
            "\\sqrt{"
            //
            "}{"
            // 
            "}"
        }
    }
}
