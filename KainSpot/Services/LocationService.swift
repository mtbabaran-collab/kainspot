//
//  LocationService.swift
//  KainSpot
//
//  Small wrapper around CLLocationManager that asks for "When In Use" permission and reports one location.
//  Course week: Week 6 (Core Location with graceful handling of every authorization state).
//

import CoreLocation
import Foundation

/// Hides CLLocationManager details from view controllers: they set two closures and call `requestWhenInUse()`.
/// Denied or restricted access calls `onDenied` instead of crashing, so the UI can show friendly text.
final class LocationService: NSObject, CLLocationManagerDelegate {

    /// Called on the main thread with the user's latest location.
    var onUpdate: ((CLLocation) -> Void)?
    /// Called on the main thread when location is off, denied or restricted.
    var onDenied: (() -> Void)?

    private let manager = CLLocationManager()
    /// Ignore the automatic authorization callback CLLocationManager fires on creation until a screen asks.
    private var isRequested = false

    override init() {
        super.init()
        manager.delegate = self
        // A food-spot distance only needs ~100 m accuracy, which is faster and kinder to the battery.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Asks for permission if needed, otherwise requests a single location fix.
    func requestWhenInUse() {
        isRequested = true
        handle(manager.authorizationStatus)
    }

    /// Stops any pending updates (call when leaving the screen).
    func stop() {
        isRequested = false
        manager.stopUpdatingLocation()
    }

    /// One switch for every authorization state so new/unknown states fall back safely to "denied".
    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            notifyDenied()
        @unknown default:
            notifyDenied()
        }
    }

    private func notifyDenied() {
        DispatchQueue.main.async { [weak self] in
            self?.onDenied?()
        }
    }

    // MARK: - CLLocationManagerDelegate

    /// Fires after the user answers the permission alert (and when settings change).
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRequested else { return }
        let status = manager.authorizationStatus
        // Still waiting for the user's answer; nothing to report yet.
        guard status != .notDetermined else { return }
        handle(status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(location)
        }
    }

    /// requestLocation() requires this method; a denial is surfaced, other errors (e.g. no GPS fix
    /// in the simulator) are only logged so the screen keeps its fallback text.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied {
            notifyDenied()
        } else {
            print("LocationService: location failed: \(error)")
        }
    }
}
