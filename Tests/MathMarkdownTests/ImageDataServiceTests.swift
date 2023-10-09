//
//  ImageDataServiceTests.swift
//  
//
//  Created by Peter Tang on 23/9/2023.
//

import XCTest
@testable import MathMarkdown
import Markdown

final class ImageDataServiceTests: XCTestCase {

    private actor TestNotification: ImageOpNotification, ImageOpCompletion {
        func fileUrl(resource: String) async -> URL? {
            nil
        }
        
        let expectation: XCTestExpectation
        private let totalTasks: Int
        private var asyncReturns: Int = 0

        init(expectation: XCTestExpectation, sampleCount count: Int) {
            self.expectation = expectation
            self.totalTasks = count
        }
        func notify(key: String, error: NSError?) async {
            XCTAssertNil(error)
            asyncReturns += 1
            if asyncReturns >= totalTasks {
                await completion()
            }
        }
        func completion() async {
            expectation.fulfill()
        }
    }
    func testUrlAttributes() {
        let networkSamples = [
            ("label1", URL(string: "https://beltoforion.de/en/barnes-hut-galaxy-simulator/images/barnes_hut_en.svg")),
            ("label2", URL(string: "https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png"))
        ]
        var grouping: [String: [(String, URL)]] = [:]
        var latestList = [(String, URL)]()
        var latestHost = ""
        // networkSamples.forEach { label, url in
        //     if let url = url, let host = url.host(), host == latestHost {
        //         latestList.append((label, url))
        //     } else if let url = url {
        //         grouping[latestHost] = latestList
        //         latestList = [(label, url)]
        //         latestHost = url.host() ?? ""
        //     }
        // }
    }
    func testConcurrentNetworkImagesScripts() throws {
        // Create an expectation for an asynchronous task.
        let expectation = XCTestExpectation(description: "SwiftMathImage asynchronous generation.")
        var range: SourceRange { SourceRange.random() }

        let networkSamples = [
            URL(string: "https://beltoforion.de/en/barnes-hut-galaxy-simulator/images/barnes_hut_en.svg"),
            URL(string: "https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png")
        ].compactMap{ $0 }.map{ (range.description, $0)}
        
        let notification = TestNotification(expectation: expectation, sampleCount: networkSamples.count)
        
        ImageDataService.shared.networkImages(networkSamples, notify: notification)
        wait(for: [expectation], timeout: 10)
    }
    func testConcurrentSwiftMathImagesScripts() throws {
        let expectation = XCTestExpectation(description: "SwiftMathImage asynchronous generation.")
        var range: SourceRange { SourceRange.random() }
        let latexSamples = Latex.samples.map { sample in (range.description, sample) }

        let notification = TestNotification(expectation: expectation, sampleCount: latexSamples.count)

        ImageDataService.shared.latexImages(latexSamples, fontSize: 12, textColor: .white, notify: notification)
        
        wait(for: [expectation], timeout: 5)
        latexSamples.enumerated().forEach { [weak self] index, sample in
            let (range, _) = sample
            guard let image = ImageCacheManager.shared.get(key: range), 
                let imageData = image
                // .flipped(flipHorizontally: true, flipVertically: false)
                .pngData() else { return }
            self?.saveImage(fileName: "\(index)", pngData: imageData)
        }
    }
    func prepareMarkdown(resource: String = "example") -> MathMarkdown? {
        guard let testFrameworkResourceBundleUrl = Bundle.module.url(forResource: resource, withExtension: "md"),
              let fileContent = try? String(contentsOf: testFrameworkResourceBundleUrl, encoding: .utf8) else { return nil }
        return MathMarkdown(parsing: fileContent)
    }
    func saveImage(fileName: String, pngData: Data) {
        let imageFileURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("image-\(fileName).png"))
        try? pngData.write(to: imageFileURL, options: [.atomicWrite])
        print("\(#function) \(imageFileURL.path)")
    }
}
extension SourceRange {
    static func random() -> Self {
        let lower = SourceLocation(line: .random(in: 0 ..< 100), column: .random(in: 0 ..< 300), source: nil)
        let upper = SourceLocation(line: .random(in: 200 ..< 300), column: .random(in: 0 ..< 300), source: nil)
        return SourceRange(uncheckedBounds: (lower: lower, upper: upper))
    }
}
enum Latex {
    static let samples: [String] = [
        #"(a_1 + a_2)^2 = a_1^2 + 2a_1a_2 + a_2^2"#,
        #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#,
        #"\sigma = \sqrt{\frac{1}{N}\sum_{i=1}^N (x_i - \mu)^2}"#,
        #"\neg(P\land Q) \iff (\neg P)\lor(\neg Q)"#,
        #"\cos(\theta + \varphi) = \cos(\theta)\cos(\varphi) - \sin(\theta)\sin(\varphi)"#,
        #"\lim_{x\to\infty}\left(1 + \frac{k}{x}\right)^x = e^k"#,
        #"f(x) = \int\limits_{-\infty}^\infty\hat f(\xi)\,e^{2 \pi i \xi x}\,\mathrm{d}\xi"#,
        #"{n \brace k} = \frac{1}{k!}\sum_{j=0}^k (-1)^{k-j}\binom{k}{j}(k-j)^n"#,
        #"\int_{-\infty}^{\infty} \! e^{-x^2} dx = \sqrt{\pi}"#,
        #"\frac{1}{n}\sum_{i=1}^{n}x_i \geq \sqrt[n]{\prod_{i=1}^{n}x_i}"#,
        #"\left(\sum_{k=1}^n a_k b_k \right)^2 \le \left(\sum_{k=1}^n a_k^2\right)\left(\sum_{k=1}^n b_k^2\right)"#,
        #"\left( \sum_{k=1}^n a_k b_k \right)^2 \leq \left( \sum_{k=1}^n a_k^2 \right) \left( \sum_{k=1}^n b_k^2 \right)"#,
        #"i\hbar\frac{\partial}{\partial t}\mathbf\Psi(\mathbf{x},t) = -\frac{\hbar}{2m}\nabla^2\mathbf\Psi(\mathbf{x},t) + V(\mathbf{x})\mathbf\Psi(\mathbf{x},t)"#,
        #"""
            \begin{gather}
            \dot{x} = \sigma(y-x) \\
            \dot{y} = \rho x - y - xz \\
            \dot{z} = -\beta z + xy"
            \end{gather}
        """#,
        #"""
            \vec \bf V_1 \times \vec \bf V_2 =  \begin{vmatrix}
            \hat \imath &\hat \jmath &\hat k \\
            \frac{\partial X}{\partial u} & \frac{\partial Y}{\partial u} & 0 \\
            \frac{\partial X}{\partial v} & \frac{\partial Y}{\partial v} & 0
            \end{vmatrix}
        """#,
        #"""
            \begin{eqalign}
            \nabla \cdot \vec{\bf E} & = \frac {\rho} {\varepsilon_0} \\
            \nabla \cdot \vec{\bf B} & = 0 \\
            \nabla \times \vec{\bf E} &= - \frac{\partial\vec{\bf B}}{\partial t} \\
            \nabla \times \vec{\bf B} & = \mu_0\vec{\bf J} + \mu_0\varepsilon_0 \frac{\partial\vec{\bf E}}{\partial t}
            \end{eqalign}
        """#,
        #"\log_b(x) = \frac{\log_a(x)}{\log_a(b)}"#,
        #"""
            \begin{pmatrix}
            a & b\\ c & d
            \end{pmatrix}
            \begin{pmatrix}
            \alpha & \beta \\ \gamma & \delta
            \end{pmatrix} =
            \begin{pmatrix}
            a\alpha + b\gamma & a\beta + b \delta \\
            c\alpha + d\gamma & c\beta + d \delta
            \end{pmatrix}
        """#,
        #"""
            \frak Q(\lambda,\hat{\lambda}) =
            -\frac{1}{2} \mathbb P(O \mid \lambda ) \sum_s \sum_m \sum_t \gamma_m^{(s)} (t) +\\
            \quad \left( \log(2 \pi ) + \log \left| \cal C_m^{(s)} \right| +
            \left( o_t - \hat{\mu}_m^{(s)} \right) ^T \cal C_m^{(s)-1} \right)
        """#
    ]
}
