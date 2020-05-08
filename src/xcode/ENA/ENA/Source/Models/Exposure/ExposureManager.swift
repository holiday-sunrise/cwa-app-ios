//
//  ExposureManager.swift
//  ENA
//
//  Created by Steinmetz, Conrad on 01.05.20.
//

import ExposureNotification
import Foundation

enum ExposureNotificationError: Error {
    case exposureNotificationRequired
    case exposureNotificationAuthorization
}

struct Preconditions: OptionSet {
    let rawValue: Int

    static let authorized   = Preconditions(rawValue: 1 << 0)
    static let enabled      = Preconditions(rawValue: 1 << 1)
    static let active       = Preconditions(rawValue: 1 << 2)

    static let all: Preconditions = [.authorized, .enabled, .active]
}

/**
*   @brief    Wrapper for ENManager to avoid code duplication and to abstract error handling
*/
final class ExposureManager {

    typealias CompletionHandler = ((ExposureNotificationError?) -> Void)

    private let manager: ENManager

    init() {
        manager = ENManager()
    }

    // MARK: - Activation

    /// Activates `ENManager` and asks user for permission to enable ExposureNotification.
    /// If the user declines, completion handler will set the error to exposureNotificationRequired
    func activate(completion: @escaping CompletionHandler) {
        manager.activate { (activationError) in
            if let activationError = activationError {
                logError(message: "Failed to activate ENManager: \(activationError.localizedDescription)")
                self.handleENError(error: activationError, completion: completion)
                return
            }
        }
    }

    // MARK: - Enable

    func enable(completion: @escaping CompletionHandler) {
        changeEnabled(to: true, completion: completion)
    }

    func disable(completion: @escaping CompletionHandler) {
        changeEnabled(to: false, completion: completion)
    }

    func preconditions() -> Preconditions {
        var preconditions: Preconditions = []

        if ENManager.authorizationStatus == ENAuthorizationStatus.authorized { preconditions.insert(.authorized) }
        if manager.exposureNotificationEnabled { preconditions.insert(.enabled) }
        if manager.exposureNotificationStatus == .active { preconditions.insert(.active) }

        return preconditions
    }

    private func changeEnabled(to status: Bool, completion: @escaping CompletionHandler) {
        if self.manager.exposureNotificationEnabled != status {
            self.manager.setExposureNotificationEnabled(status) { error in
                if let error = error {
                    logError(message: "Failed to change ENManager.setExposureNotificationEnabled to \(status): \(error.localizedDescription)")
                    self.handleENError(error: error, completion: completion)
                    return
                }
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    // MARK: - Diagnosis Keys

    /// Wrapper for `ENManager.getDiagnosisKeys`. You have to call `ExposureManager.activate` before calling this method.
    func accessDiagnosisKeys(completionHandler: @escaping ENGetDiagnosisKeysHandler) {
        if !manager.exposureNotificationEnabled {
            let error = ENError(.notEnabled)
            logError(message: error.localizedDescription)
            completionHandler(nil, error)
            return
        }
        manager.getDiagnosisKeys(completionHandler: completionHandler)
    }

    // MARK: - Error Handling

    private func handleENError(error: Error, completion: @escaping CompletionHandler) {
        if let error = error as? ENError {
            switch error.code {
            case .notAuthorized:
                completion(ExposureNotificationError.exposureNotificationAuthorization)
            case .notEnabled:
                completion(ExposureNotificationError.exposureNotificationRequired)
            default:
                // TODO: Add missing cases
                let error = "[ExposureManager] Not implemented \(error.localizedDescription)"
                logError(message: error)
                fatalError(error)
            }
        } else {
            let error = "[ExposureManager] Not implemented \(error.localizedDescription)"
            logError(message: error)
            fatalError(error)
        }
    }

    deinit {
        manager.invalidate()
    }
}
