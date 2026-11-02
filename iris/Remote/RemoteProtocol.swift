//
//  RemoteProtocol.swift
//  iris
//

import Foundation
import SwiftUI

/// The language spoken with Iris on the computer. Mirrors `src/shared/remote/protocol.ts` in atm-iris-desktop:
/// change one, change the other, and bump `version` when they stop understanding each other.
enum RemoteProtocol {
    static let version = 1
    static let serviceType = "_iris._tcp"
    static let codeLength = 6
    static let defaultPort: UInt16 = 47_831
}

// MARK: State (what the computer tells us)

struct RemoteState: Codable, Equatable {
    var churchName: String
    var items: [RemoteItem]
    /// The element selected on the computer.
    var openId: String?
    /// What is on the screens.
    var live: Live?
    var isCleared: Bool
    var playback: Playback?
    var volume: Double
    var backgroundId: String?
    var backgrounds: [RemoteBackground]
    var sounds: [RemoteSound]
    var countdown: Countdown?
    var service: Service?
    // Optional: a computer still on Iris 1.1.1 does not send them.
    var serviceTypes: [Named]?
    var selectedServiceTypeId: String?
    var canChooseService: Bool?
    var people: [Named]?
    var library: [LibraryEntry]?
    var bibles: [Bible]?
    var selectedBible: String?

    struct Named: Codable, Equatable, Identifiable {
        var id: String
        var name: String
    }

    struct LibraryEntry: Codable, Equatable, Identifiable {
        var id: String
        var kind: Kind
        var title: String
        var durationSeconds: Double?

        enum Kind: String, Codable { case image, video }
    }

    struct Bible: Codable, Equatable, Identifiable {
        var code: String
        var name: String
        var id: String { code }
    }

    struct Live: Codable, Equatable {
        var id: String
        var slide: Int
    }

    struct Playback: Codable, Equatable {
        var id: String
        var kind: Kind
        var title: String
        var isPlaying: Bool
        /// Seconds played when the computer built this state; see `RemoteClient.position(of:at:)`.
        var position: Double
        var duration: Double
        var isLooping: Bool
        var hasError: Bool

        enum Kind: String, Codable { case track, video }
    }

    struct Countdown: Codable, Equatable {
        var remainingSeconds: Double
        var isRunning: Bool
        var label: String?
    }

    struct Service: Codable, Equatable {
        var name: String
        var phase: Phase
        var blocks: [Block]
        /// Seconds the current block had run when the computer built this state.
        var elapsedSeconds: Double
        var canAdvance: Bool

        enum Phase: String, Codable { case notStarted, running, finished }

        struct Block: Codable, Equatable, Identifiable {
            var name: String
            var plannedSeconds: Double
            var status: Status
            var leader: String?
            var leaderId: String?
            var id: String { name + String(plannedSeconds) }

            enum Status: String, Codable { case done, current, pending, skipped }
        }
    }
}

struct RemoteItem: Codable, Equatable, Identifiable {
    var id: String
    var kind: Kind
    var title: String
    var subtitle: String?
    var slides: [RemoteSlide]
    /// Has a track or a video to play.
    var isPlayable: Bool
    var backgroundId: String?
    /// An image or video element: its picture is asked for with `RemoteClient.wantThumbnail`.
    var thumbnailId: String?

    enum Kind: String, Codable {
        case song, track, image, video, youtube, bible

        var systemImage: String {
            switch self {
            case .song: "music.note"
            case .track: "waveform"
            case .bible: "book.closed"
            case .video, .youtube: "play.rectangle"
            case .image: "photo"
            }
        }

        var title: String {
            switch self {
            case .song: "Canción"
            case .track: "Pista"
            case .bible: "Biblia"
            case .video: "Video"
            case .youtube: "YouTube"
            case .image: "Imagen"
            }
        }
    }

    /// The slides with their position, which is how the computer is told which one to show.
    var numberedSlides: [NumberedSlide] {
        slides.enumerated().map { NumberedSlide(index: $0.offset, label: $0.element.label, text: $0.element.text) }
    }
}

struct RemoteSlide: Codable, Equatable {
    var label: String?
    var text: String
}

struct NumberedSlide: Identifiable, Equatable {
    var index: Int
    var label: String?
    var text: String
    var id: Int { index }
}

struct RemoteBackground: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var colors: [String]
    /// "gradient", "image" or "video" (missing from a computer before Iris 1.3).
    var kind: String?
    var thumbnailId: String?

    var isVideo: Bool { kind == "video" }
}

struct RemoteSound: Codable, Equatable, Identifiable {
    var id: String
    var title: String
}

// MARK: Commands (what we ask of the computer). Nothing here adds, removes or edits content.

enum RemoteCommand {
    enum PlaybackAction: String { case play, pause, stop, restart, loopOn = "loop-on", loopOff = "loop-off" }
    enum CountdownAction: String { case start, pause, resume, hide }

    case select(id: String)
    case showSlide(id: String, slide: Int)
    case setCleared(Bool)
    case playback(PlaybackAction)
    case seek(seconds: Double)
    case volume(Double)
    case setBackground(id: String?)
    /// `label` is the optional text shown with the countdown ("Empezamos en…"), like on the computer.
    case countdown(CountdownAction, seconds: Int? = nil, label: String? = nil)
    case playSound(id: String)
    case nextBlock
    case finishService
    case chooseService(id: String)
    /// Someone listed (`personId`) or a new name, added to the people like on the computer.
    case setLeader(block: Int, personId: String?, name: String?)
    case presentMedia(id: String)
    /// An extra block for this service only, placed at `at` (the computer never puts it before the running one).
    case addBlock(name: String, minutes: Int, at: Int)
    /// Shown once on the screens; it never joins the service.
    case presentBible(translation: String, bookId: String, chapter: Int, from: Int, to: Int)

    var json: [String: Any] {
        switch self {
        case .select(let id): ["type": "select", "id": id]
        case .showSlide(let id, let slide): ["type": "show-slide", "id": id, "slide": slide]
        case .setCleared(let value): ["type": "set-cleared", "value": value]
        case .playback(let action): ["type": "playback", "action": action.rawValue]
        case .seek(let seconds): ["type": "seek", "seconds": seconds]
        case .volume(let value): ["type": "volume", "value": value]
        case .setBackground(let id): ["type": "set-background", "id": id as Any? ?? NSNull()]
        case .countdown(let action, let seconds, let label):
            ["type": "countdown", "action": action.rawValue]
                .merging(seconds.map { ["seconds": $0] } ?? [:]) { a, _ in a }
                .merging(label.map { ["label": $0] } ?? [:]) { a, _ in a }
        case .playSound(let id): ["type": "play-sound", "id": id]
        case .nextBlock: ["type": "next-block"]
        case .finishService: ["type": "finish-service"]
        case .chooseService(let id): ["type": "choose-service", "id": id]
        case .setLeader(let block, let personId, let name):
            ["type": "set-leader", "block": block]
                .merging(personId.map { ["personId": $0] } ?? [:]) { a, _ in a }
                .merging(name.map { ["name": $0] } ?? [:]) { a, _ in a }
        case .presentMedia(let id): ["type": "present-media", "id": id]
        case .addBlock(let name, let minutes, let at): ["type": "add-block", "name": name, "minutes": minutes, "at": at]
        case .presentBible(let translation, let bookId, let chapter, let from, let to):
            ["type": "present-bible", "translation": translation, "bookId": bookId, "chapter": chapter, "from": from, "to": to]
        }
    }
}

// MARK: Wire messages

enum ServerMessage: Decodable {
    case paired(token: String, computerName: String)
    /// `nil`: the computer is not on the service screen (Settings, Times…), so there is nothing to control yet.
    case state(RemoteState?)
    case error(RemoteFailure)
    case bye(reason: String)
    case response(id: String, RemoteResponse)

    private enum Keys: String, CodingKey { case type, token, computerName, state, code, message, reason, id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "paired":
            self = .paired(
                token: try container.decode(String.self, forKey: .token),
                computerName: try container.decode(String.self, forKey: .computerName)
            )
        case "state":
            self = .state(try container.decode(RemoteState?.self, forKey: .state))
        case "error":
            self = .error(RemoteFailure(
                code: try container.decode(String.self, forKey: .code),
                message: try container.decode(String.self, forKey: .message)
            ))
        case "bye":
            self = .bye(reason: try container.decode(String.self, forKey: .reason))
        case "response":
            self = .response(id: try container.decode(String.self, forKey: .id), try RemoteResponse(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown message")
        }
    }
}

/// The answer to a question (`RemoteClient.request`): the field that matches the question, or `error`.
struct RemoteResponse: Decodable {
    var books: [BibleBook]?
    var verses: [BibleVerse]?
    /// A thumbnail: a JPEG in base64.
    var image: String?
    var error: String?
}

struct BibleBook: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var testament: String
    var chapterCount: Int
}

struct BibleVerse: Decodable, Identifiable, Hashable {
    var number: Int
    var text: String
    var id: Int { number }
}

/// A refusal from the computer. `message` already comes in Spanish.
struct RemoteFailure: Error, Equatable {
    var code: String
    var message: String
}

extension Color {
    /// "#2A1658" (the computer's gradient stops). Anything else falls back to black.
    init(cssHex: String) {
        let digits = cssHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        self.init(hex: UInt32(digits, radix: 16) ?? 0)
    }
}
