//
//  SpotDetailViewController.swift
//  KainSpot — Controller layer
//  One spot in detail: info, map with the spot + FEU Diliman, the user's live distance, and "Add My Photo".
//  Course week: Week 6 (MapKit, Core Location, PHPicker photo library) + Week 7 (saving the photo to disk).
//

import UIKit
import MapKit
import CoreLocation
import PhotosUI

/// Detail screen for a single `Spot` passed in from the list.
final class SpotDetailViewController: UIViewController {

    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var metaLabel: UILabel!
    @IBOutlet weak var blurbLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var userDistanceLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoButton: UIButton!

    /// Set by SpotListViewController before the segue runs.
    var spot: Spot?

    private let locationService = LocationService()
    private let photoStore = PhotoStore.spotPhotos
    private var spotAnnotation: MKPointAnnotation?
    private var feuAnnotation: MKPointAnnotation?

    /// File name is derived from the spot id (not the Core Data object), so a re-sync that
    /// deletes and re-inserts spots never loses the user's photo.
    private var photoFileName: String? {
        guard let id = spot?.id, !id.isEmpty else { return nil }
        return "spot-\(id).jpg"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        applyTheme()
        mapView.delegate = self

        guard let spot = spot else {
            // Defensive: opened without a spot (should not happen) — show a friendly state instead of crashing.
            title = "Spot"
            nameLabel.text = "Spot not found"
            photoButton.isEnabled = false
            return
        }

        populate(with: spot)
        configureMap(for: spot)
        restoreSavedPhoto()
        startLocationUpdates()
    }

    /// Stop GPS work when leaving the screen to save battery.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            locationService.stop()
        }
    }

    // MARK: - Setup

    /// Corner radius / button styling in code, colors from the shared Theme.
    private func applyTheme() {
        Theme.stylePrimaryButton(photoButton)
        photoImageView.layer.cornerRadius = Theme.cardCornerRadius
        photoImageView.layer.cornerCurve = .continuous
        photoImageView.clipsToBounds = true
        photoImageView.backgroundColor = Theme.card
        mapView.layer.cornerRadius = Theme.cardCornerRadius
        mapView.layer.cornerCurve = .continuous
        mapView.clipsToBounds = true
        nameLabel.textColor = Theme.ink
        metaLabel.textColor = Theme.primary
        blurbLabel.textColor = Theme.ink
        addressLabel.textColor = Theme.muted
        distanceLabel.textColor = Theme.ink
        userDistanceLabel.textColor = Theme.muted
    }

    /// Fills the text labels; the distance from campus is fixed so it is computed once here.
    private func populate(with spot: Spot) {
        let name = spot.name ?? "Food spot"
        title = name
        nameLabel.text = name
        let price = PriceLevel(rawValue: spot.priceLevel)?.symbol ?? "₱"
        let category = spot.category ?? ""
        metaLabel.text = "\(category) · \(price) · ★ \(String(format: "%.1f", spot.rating))"
        blurbLabel.text = spot.blurb ?? ""
        let address = spot.address ?? ""
        addressLabel.text = address.isEmpty ? "" : "📍 \(address)"

        let km = DistanceCalculator.kilometers(
            from: DistanceCalculator.feuDiliman,
            to: .init(latitude: spot.latitude, longitude: spot.longitude))
        distanceLabel.text = "\(DistanceCalculator.formatted(km)) from FEU Diliman"
        userDistanceLabel.text = "Finding your location…"
    }

    /// Two pins (spot + FEU Diliman) and a region padded so both are always on screen.
    private func configureMap(for spot: Spot) {
        let spotCoordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let feuCoordinate = CLLocationCoordinate2D(latitude: DistanceCalculator.feuDiliman.latitude,
                                                   longitude: DistanceCalculator.feuDiliman.longitude)

        let spotPin = MKPointAnnotation()
        spotPin.coordinate = spotCoordinate
        spotPin.title = spot.name ?? "Food spot"
        spotPin.subtitle = spot.category

        let feuPin = MKPointAnnotation()
        feuPin.coordinate = feuCoordinate
        feuPin.title = "FEU Diliman"
        feuPin.subtitle = "Campus"

        spotAnnotation = spotPin
        feuAnnotation = feuPin
        mapView.addAnnotations([spotPin, feuPin])

        // Centre between the two points; span is the gap between them plus 60% padding (min ~1 km).
        let center = CLLocationCoordinate2D(latitude: (spotCoordinate.latitude + feuCoordinate.latitude) / 2,
                                            longitude: (spotCoordinate.longitude + feuCoordinate.longitude) / 2)
        let latDelta = max(abs(spotCoordinate.latitude - feuCoordinate.latitude) * 1.6, 0.01)
        let lonDelta = max(abs(spotCoordinate.longitude - feuCoordinate.longitude) * 1.6, 0.01)
        let region = MKCoordinateRegion(center: center,
                                        span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
    }

    /// Loads a previously chosen photo from Documents so it survives app relaunches.
    private func restoreSavedPhoto() {
        guard let fileName = photoFileName else {
            showPhoto(nil)
            return
        }
        showPhoto(photoStore.load(named: fileName))
    }

    /// Updates the image view and flips the button title between "Add" and "Change".
    private func showPhoto(_ image: UIImage?) {
        if let image = image {
            photoImageView.contentMode = .scaleAspectFill
            photoImageView.image = image
            photoButton.setTitle("Change My Photo", for: .normal)
        } else {
            photoImageView.contentMode = .center
            photoImageView.tintColor = Theme.muted
            photoImageView.image = UIImage(systemName: "photo",
                                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 44))
            photoButton.setTitle("Add My Photo", for: .normal)
        }
    }

    /// Asks for location; callbacks may come from Core Location's thread, so hop to main before touching UI.
    private func startLocationUpdates() {
        locationService.onUpdate = { [weak self] location in
            DispatchQueue.main.async {
                self?.updateUserDistance(from: location)
            }
        }
        locationService.onDenied = { [weak self] in
            DispatchQueue.main.async {
                self?.userDistanceLabel.text = "Turn on location to see how far you are"
            }
        }
        locationService.requestWhenInUse()
    }

    /// Straight-line distance from where the user is standing to the spot.
    private func updateUserDistance(from location: CLLocation) {
        guard let spot = spot else { return }
        let km = DistanceCalculator.kilometers(
            from: .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            to: .init(latitude: spot.latitude, longitude: spot.longitude))
        userDistanceLabel.text = "You are \(DistanceCalculator.formatted(km)) away"
        mapView.showsUserLocation = true
    }

    // MARK: - Actions

    /// Opens the system photo picker (no photo-library permission prompt needed with PHPicker).
    @IBAction func addPhotoTapped(_ sender: UIButton) {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Saves the picked image under the spot's fixed file name, then shows it.
    private func savePickedImage(_ image: UIImage) {
        guard let fileName = photoFileName else { return }
        do {
            _ = try photoStore.save(image, named: fileName)
            showPhoto(image)
        } catch {
            showAlert(title: "Couldn't save photo", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension SpotDetailViewController: PHPickerViewControllerDelegate {

    /// Loads the chosen item as a UIImage in the background, then saves/updates UI on the main thread.
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            let image = object as? UIImage
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let image = image {
                    self.savePickedImage(image)
                } else {
                    let message = error?.localizedDescription ?? "That photo couldn't be loaded."
                    self.showAlert(title: "Photo not loaded", message: message)
                }
            }
        }
    }
}

// MARK: - MKMapViewDelegate

extension SpotDetailViewController: MKMapViewDelegate {

    /// Orange marker for the food spot, teal for campus, default blue dot for the user.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let point = annotation as? MKPointAnnotation else { return nil }
        let identifier = "KainSpotPin"
        let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: point, reuseIdentifier: identifier)
        marker.annotation = point
        marker.canShowCallout = true
        if point === feuAnnotation {
            marker.markerTintColor = Theme.accent
            marker.glyphImage = UIImage(systemName: "graduationcap.fill")
        } else {
            marker.markerTintColor = Theme.primary
            marker.glyphImage = UIImage(systemName: "fork.knife")
        }
        return marker
    }
}
