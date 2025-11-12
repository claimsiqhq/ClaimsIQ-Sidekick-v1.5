//
//  LocationManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var isLocationEnabled = false
    @Published var heading: CLHeading?
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private let geocoder = CLGeocoder()
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        checkLocationAuthorization()
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        guard isLocationEnabled else { return }
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    func reverseGeocodeLocation(_ location: CLLocation) async throws -> String {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        
        var addressComponents: [String] = []
        
        if let streetNumber = placemark.subThoroughfare {
            addressComponents.append(streetNumber)
        }
        if let street = placemark.thoroughfare {
            addressComponents.append(street)
        }
        if let city = placemark.locality {
            addressComponents.append(city)
        }
        if let state = placemark.administrativeArea {
            addressComponents.append(state)
        }
        if let zip = placemark.postalCode {
            addressComponents.append(zip)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    func getAddressFromCoordinates(latitude: Double, longitude: Double) async throws -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return try await reverseGeocodeLocation(location)
    }
    
    // MARK: - Private Methods
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            isLocationEnabled = false
        case .restricted, .denied:
            isLocationEnabled = false
        case .authorizedAlways, .authorizedWhenInUse:
            isLocationEnabled = true
            startUpdatingLocation()
        @unknown default:
            isLocationEnabled = false
        }
        authorizationStatus = locationManager.authorizationStatus
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
        
        // Update address in background
        Task {
            do {
                let address = try await reverseGeocodeLocation(location)
                await MainActor.run {
                    self.currentAddress = address
                }
            } catch {
                print("Failed to reverse geocode: \(error)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error)")
        
        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
}

// MARK: - Location Metadata

extension LocationManager {
    func createLocationMetadata() -> LocationMetadata {
        return LocationMetadata(
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            altitude: currentLocation?.altitude,
            horizontalAccuracy: currentLocation?.horizontalAccuracy,
            verticalAccuracy: currentLocation?.verticalAccuracy,
            heading: heading?.trueHeading,
            speed: currentLocation?.speed,
            address: currentAddress,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types

struct LocationMetadata: Codable {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let heading: Double?
    let speed: Double?
    let address: String?
    let timestamp: Date
}

enum LocationError: LocalizedError {
    case geocodingFailed
    case locationServiceDisabled
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .geocodingFailed:
            return "Failed to get address from location"
        case .locationServiceDisabled:
            return "Location services are disabled"
        case .unauthorized:
            return "Location access not authorized"
        }
    }
}
