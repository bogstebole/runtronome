import Foundation
import CoreLocation
import Observation

/// Tracks distance covered during a run so distance-based phases can advance
/// hands-free — the phone stays in an armband, screen off. Uses background GPS
/// (the `location` background mode) alongside the metronome's audio session.
///
/// Only cumulative `distance` matters here: the metronome runs off its own
/// timer, and the flow coordinator compares this distance against the current
/// phase's goal to know when to move on.
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {
    /// Metres covered since the last `start()`.
    private(set) var distance: Double = 0
    private(set) var isTracking = false
    /// `false` once the user denies location — the UI falls back to the manual
    /// "NEXT" bar for distance phases.
    private(set) var isAuthorized = true

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        // Requires the `location` background mode in Info.plist — set here so a
        // pocketed, screen-off phone keeps measuring.
        manager.allowsBackgroundLocationUpdates = true
    }

    // MARK: Control

    func start() {
        distance = 0
        lastLocation = nil
        isTracking = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        isTracking = false
        lastLocation = nil
        manager.stopUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            isAuthorized = false
        default:
            isAuthorized = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        for location in locations {
            // Reject weak fixes and stale points so a jittery GPS lock doesn't
            // inflate the distance while you're standing still.
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 25 else { continue }
            guard location.timestamp.timeIntervalSinceNow > -5 else { continue }

            if let last = lastLocation {
                let step = location.distance(from: last)
                // Ignore sub-metre noise and implausible jumps.
                if step > 1, step < 100 { distance += step }
            }
            lastLocation = location
        }
    }
}
