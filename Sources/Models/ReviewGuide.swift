// ABOUTME: Decodable model for .factoryfloor-state/review.json.
// ABOUTME: Parsed on demand in ChangesView to order files and show inline annotations.

import Foundation

struct ReviewGuide: Decodable {
    struct Guide: Decodable {
        let title: String
        let summary: String
    }

    struct OrderEntry: Decodable {
        let file: String
        let reason: String
    }

    struct Annotation: Decodable {
        let file: String
        let line: Int?
        let lines: [Int]?
        let body: String
    }

    let reviewGuide: Guide
    let order: [OrderEntry]?
    let annotations: [Annotation]?

    enum CodingKeys: String, CodingKey {
        case reviewGuide = "review_guide"
        case order, annotations
    }

    /// Load and parse review.json from a worktree's .factoryfloor-state directory.
    static func load(worktreePath: String) -> ReviewGuide? {
        let url = URL(fileURLWithPath: worktreePath)
            .appendingPathComponent(".factoryfloor-state/review.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ReviewGuide.self, from: data)
    }
}
