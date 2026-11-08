import Foundation
import SwiftData

@Model
final class MemoryItem {
    var title: String = ""
    var content: String = ""
    var summary: String = ""
    var category: String = "À classer"
    var tagsStorage: String = "[]"
    var visualLabelsStorage: String = "[]"
    var reminderID: UUID = UUID()
    var reminderAt: Date? = nil
    var createdAt: Date = .now
    var isSelected: Bool = false

    var tags: [String] {
        get { Self.decode(tagsStorage) }
        set { tagsStorage = Self.encode(newValue) }
    }

    var visualLabels: [String] {
        get { Self.decode(visualLabelsStorage) }
        set { visualLabelsStorage = Self.encode(newValue) }
    }

    init(title: String, content: String, createdAt: Date = .now) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }

    private static func encode(_ values: [String]) -> String {
        guard
            let data = try? JSONEncoder().encode(values),
            let value = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return value
    }

    private static func decode(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
