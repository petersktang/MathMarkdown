// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MathMarkdown",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MathMarkdown",
            targets: ["MathMarkdown"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/petersktang/SwiftMath.git", branch: "main"),
        .package(url: "https://github.com/groue/Semaphore.git", branch: "main"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MathMarkdown",
            dependencies: [
                .product(name: "SwiftMath", package: "swiftmath"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Semaphore", package: "Semaphore"),
            ]),
        .target(name: "MathLatex",
           dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
           ]),
        .testTarget(
            name: "MathMarkdownTests",
            dependencies: [
                "MathMarkdown",
                .product(name: "SwiftMath", package: "swiftmath"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Semaphore", package: "Semaphore"),
            ],
            resources: [
                .copy("example.md"),
                .copy(#"img/amgm.png"#),
                .copy(#"img/bubble.png"#),
                .copy(#"img/calculus.png"#),
                .copy(#"img/cases.png"#),
                .copy(#"img/cauchyintegral.png"#),
                .copy(#"img/cauchyschwarz.png"#),
                .copy(#"img/cross.png"#),
                .copy(#"img/demorgan.png"#),
                .copy(#"img/gaussintegral.png"#),
                .copy(#"img/log.png"#),
                .copy(#"img/long.png"#),
                .copy(#"img/lorentz.png"#),
                .copy(#"img/matrixmult.png"#),
                .copy(#"img/maxwell.png"#),
                .copy(#"img/quadratic.png"#),
                .copy(#"img/ramanujan.png"#),
                .copy(#"img/schroedinger.png"#),
                .copy(#"img/square.png"#),
                .copy(#"img/st.png"#),
                .copy(#"img/standard.png"#),
                .copy(#"img/stirling.png"#),
                .copy(#"img/trig.png"#),
            ]),
        .testTarget(name: "MathLatexTests",
           dependencies: [
                "MathLatex",
                .product(name: "Parsing", package: "swift-parsing")
           ]),
    ]
)
