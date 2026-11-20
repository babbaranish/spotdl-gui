import Foundation

enum SongState: Equatable {
    case working(String), done, skipped, failed
}

struct SongRow: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var state: SongState
    var isFinished: Bool { state == .done || state == .skipped || state == .failed }
}

enum JobState: Equatable {
    case waiting, fetching, downloading, done, failed(String), cancelled
    var isActive: Bool { self == .waiting || self == .fetching || self == .downloading }
}
