import Foundation

/// Finished and interrupted jobs, saved as JSON so the list survives a restart.
enum HistoryStore {
    private static var fileURL: URL {
        AppPaths.supportDirectory.appendingPathComponent("history.json")
    }

    /// Empty when the file is missing. Records that fail to decode are skipped; a file that cannot be
    /// read at all is moved to history.json.bak so the next save does not overwrite it.
    static func load() -> [JobRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? decoder.decode([Lossy].self, from: data)
        else {
            AppPaths.moveAside(fileURL)
            return []
        }
        return items.compactMap(\.record)
    }

    /// Keeps the first JobRecord.historyLimit records (newest first) and replaces the file atomically.
    static func save(_ records: [JobRecord]) {
        guard let data = try? encoder.encode(Array(records.prefix(JobRecord.historyLimit))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// One history entry, nil when it does not decode, so a bad record does not drop the rest.
    private struct Lossy: Decodable {
        let record: JobRecord?

        init(from decoder: Decoder) throws {
            record = try? decoder.singleValueContainer().decode(JobRecord.self)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
