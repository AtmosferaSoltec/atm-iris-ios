//
//  MediaDownloader.swift
//  iris
//

import Foundation
import Synchronization

/// Downloads files with a background `URLSession`, so they finish even if the app leaves the foreground.
/// Background sessions only work with a delegate, so each task keeps its destination and continuation here.
nonisolated final class MediaDownloader: NSObject, URLSessionDownloadDelegate, Sendable {
    static let sessionIdentifier = "com.atmosfera.iris.media"
    /// One per process: a background session identifier can only be used once.
    static let shared = MediaDownloader()

    private struct Pending {
        let destination: URL
        let progress: @Sendable (Double) -> Void
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let pending = Mutex<[Int: Pending]>([:])
    private let session = Mutex<URLSession?>(nil)
    /// Set by the app delegate when the system relaunches the app for finished background downloads.
    private let backgroundCompletion = Mutex<(@Sendable () -> Void)?>(nil)

    func setBackgroundCompletion(_ completion: @escaping @Sendable () -> Void) {
        backgroundCompletion.withLock { $0 = completion }
        _ = urlSession
    }

    private var urlSession: URLSession {
        session.withLock { session in
            if let session { return session }
            let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
            configuration.isDiscretionary = false
            configuration.sessionSendsLaunchEvents = true
            configuration.httpMaximumConnectionsPerHost = 2
            let created = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            session = created
            return created
        }
    }

    /// Downloads `url` to `destination`, reporting progress from 0 to 1.
    func download(_ url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(with: url)
            pending.withLock { $0[task.taskIdentifier] = Pending(destination: destination, progress: progress, continuation: continuation) }
            task.resume()
        }
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let entry = pending.withLock { $0[downloadTask.taskIdentifier] }
        entry?.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let entry = pending.withLock({ $0[downloadTask.taskIdentifier] }) else { return }
        // The temporary file disappears when this method returns: move it now.
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            return
        }
        let manager = FileManager.default
        try? manager.createDirectory(at: entry.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? manager.removeItem(at: entry.destination)
        try? manager.moveItem(at: location, to: entry.destination)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let entry = pending.withLock({ $0.removeValue(forKey: task.taskIdentifier) }) else { return }
        if let error {
            entry.continuation.resume(throwing: error)
        } else if let response = task.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            entry.continuation.resume(throwing: URLError(.badServerResponse))
        } else if FileManager.default.fileExists(atPath: entry.destination.path) {
            entry.continuation.resume()
        } else {
            entry.continuation.resume(throwing: URLError(.cannotCreateFile))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = backgroundCompletion.withLock { value in
            defer { value = nil }
            return value
        }
        DispatchQueue.main.async { completion?() }
    }
}
