//
//  SpotDetailViewController.swift
//  KainSpot — Controller layer
//  One spot in detail: info, amenities, rating stars, the Vacant Planner line, a map with emoji pins and a
//  dashed route from FEU Diliman, the user's live distance, directions, sharing and "Add My Photo".
//  Course week: Week 6 (MapKit, Core Location, PHPicker photo library) + Week 7 (saving the photo to disk).
//  Feature: UI upgrade — amenity chips, ⭐ stars, leave-by, emoji pins + dashed route, directions, share, cross-fade.
//

import UIKit
import MapKit
import CoreLocation
import PhotosUI

/// Detail screen for a single `Spot` passed in from the list, roulette or Ask.
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

    /// Set by whoever opens this screen before it loads.
    var spot: Spot?
    /// Length of the student's vacant, used for the leave-by line (defaults to one class hour).
    var vacantMinutes: Int = KainNavigator.defaultVacantMinutes

    private let locationService = LocationService()
    private let photoStore = PhotoStore.spotPhotos
    private var spotAnnotation: MKPointAnnotation?
    private var feuAnnotation: MKPointAnnotation?
    /// Walk or ride, decided by the Vacant Planner; also picks the Apple Maps directions mode.
    private var travelMode: TravelMode = .walk

    // Programmatic additions (inserted into the storyboard stack).
    private let starsLabel = UILabel()
    private let planLabel = UILabel()
    private let amenitiesStack = UIStackView()
    private let directionsButton = Theme.makePrimaryButton(title: "🧭 Get Directions", identifier: "directionsButton")

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

        addUpgradeViews()
        populate(with: spot)
        configureMap(for: spot)
        restoreSavedPhoto()
        startLocationUpdates()
        addShareButton()
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

    /// Adds stars + amenities under the meta line, the plan line under the distance, and Directions
    /// under the map. Uses the storyboard stack (the map's superview) so scrolling keeps working.
    private func addUpgradeViews() {
        guard let stack = mapView.superview as? UIStackView else { return }

        starsLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        starsLabel.textColor = .systemYellow
        starsLabel.accessibilityIdentifier = "ratingStars"

        planLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        planLabel.numberOfLines = 0
        planLabel.accessibilityIdentifier = "vacantPlanLabel"

        amenitiesStack.axis = .horizontal
        amenitiesStack.spacing = 8
        amenitiesStack.translatesAutoresizingMaskIntoConstraints = false
        let amenitiesScroll = UIScrollView()
        amenitiesScroll.showsHorizontalScrollIndicator = false
        amenitiesScroll.translatesAutoresizingMaskIntoConstraints = false
        amenitiesScroll.addSubview(amenitiesStack)
        NSLayoutConstraint.activate([
            amenitiesStack.topAnchor.constraint(equalTo: amenitiesScroll.contentLayoutGuide.topAnchor),
            amenitiesStack.bottomAnchor.constraint(equalTo: amenitiesScroll.contentLayoutGuide.bottomAnchor),
            amenitiesStack.leadingAnchor.constraint(equalTo: amenitiesScroll.contentLayoutGuide.leadingAnchor),
            amenitiesStack.trailingAnchor.constraint(equalTo: amenitiesScroll.contentLayoutGuide.trailingAnchor),
            amenitiesStack.heightAnchor.constraint(equalTo: amenitiesScroll.frameLayoutGuide.heightAnchor),
            amenitiesScroll.heightAnchor.constraint(equalToConstant: 28)
        ])

        insert(starsLabel, after: metaLabel, in: stack)
        insert(amenitiesScroll, after: starsLabel, in: stack)
        insert(planLabel, after: distanceLabel, in: stack)
        insert(directionsButton, after: mapView, in: stack)
        directionsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        directionsButton.addTarget(self, action: #selector(directionsTapped), for: .touchUpInside)
    }

    private func insert(_ newView: UIView, after anchor: UIView, in stack: UIStackView) {
        let index = stack.arrangedSubviews.firstIndex(where: { $0 === anchor }).map { $0 + 1 } ?? stack.arrangedSubviews.count
        stack.insertArrangedSubview(newView, at: index)
    }

    /// Fills the text labels; the distance from campus is fixed so it is computed once here.
    private func populate(with spot: Spot) {
        let name = spot.name ?? "Spot"
        let emoji = KainNavigator.emoji(for: spot)
        title = name
        nameLabel.text = "\(emoji) \(name)"
        let kind = KainNavigator.kind(of: spot)?.title ?? "Spot"
        let category = spot.category ?? ""
        let kindLine = category.isEmpty ? kind : "\(kind) · \(category)"
        metaLabel.text = "\(kindLine) · \(KainNavigator.priceText(for: spot))"
        starsLabel.text = starText(for: spot.rating)
        starsLabel.accessibilityLabel = "Rated \(String(format: "%.1f", spot.rating)) out of 5"
        blurbLabel.text = spot.blurb ?? ""
        let address = spot.address ?? ""
        addressLabel.text = address.isEmpty ? "" : "📍 \(address)"

        let km = KainNavigator.distanceKm(to: spot)
        distanceLabel.text = "\(DistanceCalculator.formatted(km)) from FEU Diliman"
        userDistanceLabel.text = "Finding your location…"

        // Vacant Planner: "🚶 8 min each way · Leave by 2:40 PM".
        let plan = KainNavigator.plan(for: spot, vacantMinutes: vacantMinutes)
        travelMode = plan.mode
        if plan.fits {
            planLabel.text = "\(plan.mode.emoji) \(plan.travelMinutesOneWay) min each way · \(plan.formattedLeaveBy)"
            planLabel.textColor = Theme.accent
        } else {
            planLabel.text = "\(plan.mode.emoji) \(plan.travelMinutesOneWay) min each way · Too far for a \(vacantMinutes)-min vacant"
            planLabel.textColor = Theme.muted
        }

        fillAmenities(for: spot)
    }

    /// "★★★★☆ 4.6" — rounded to the nearest whole star, clamped to 0...5.
    private func starText(for rating: Double) -> String {
        let full = min(max(Int(rating.rounded()), 0), 5)
        return String(repeating: "★", count: full) + String(repeating: "☆", count: 5 - full)
            + "  " + String(format: "%.1f", rating)
    }

    /// One pill per amenity the spot actually has, plus its opening hours.
    private func fillAmenities(for spot: Spot) {
        amenitiesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var items: [String] = []
        if spot.hasWifi { items.append("📶 WiFi") }
        if spot.hasOutlets { items.append("🔌 Outlets") }
        if spot.studentDiscount { items.append("🏷️ Student discount") }
        if spot.openLate { items.append("🌙 Open late") }
        items.append("⏰ \(hoursText(open: Int(spot.openHour), close: Int(spot.closeHour)))")
        for item in items {
            amenitiesStack.addArrangedSubview(Theme.makePillLabel(item))
        }
    }

    /// "8 AM–10 PM"; equal hours or 0–24 mean open all day.
    private func hoursText(open: Int, close: Int) -> String {
        if open == close || (open <= 0 && close >= 24) { return "Open 24 hrs" }
        return "\(hourText(open))–\(hourText(close))"
    }

    private func hourText(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 0: return "12 AM"
        case 12: return "12 PM"
        case 1..<12: return "\(h) AM"
        default: return "\(h - 12) PM"
        }
    }

    /// Share button in the navigation bar.
    private func addShareButton() {
        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped))
        share.accessibilityIdentifier = "shareButton"
        share.accessibilityLabel = "Share this spot"
        navigationItem.rightBarButtonItem = share
    }

    /// Two emoji pins (spot + FEU Diliman), a dashed line between them, and a region that fits both.
    private func configureMap(for spot: Spot) {
        let spotCoordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let feuCoordinate = DistanceCalculator.feuDiliman.clCoordinate

        let spotPin = MKPointAnnotation()
        spotPin.coordinate = spotCoordinate
        spotPin.title = spot.name ?? "Spot"
        spotPin.subtitle = spot.category

        let feuPin = MKPointAnnotation()
        feuPin.coordinate = feuCoordinate
        feuPin.title = "FEU Diliman"
        feuPin.subtitle = "Campus"

        spotAnnotation = spotPin
        feuAnnotation = feuPin
        mapView.addAnnotations([spotPin, feuPin])

        // Straight dashed "as the crow flies" line; real turn-by-turn lives in Apple Maps (Get Directions).
        let coordinates = [feuCoordinate, spotCoordinate]
        mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))

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
            showPhoto(nil, animated: false)
            return
        }
        showPhoto(photoStore.load(named: fileName), animated: false)
    }

    /// Updates the image view and flips the button title between "Add" and "Change".
    /// A newly picked photo cross-fades in instead of popping.
    private func showPhoto(_ image: UIImage?, animated: Bool) {
        let update = {
            if let image = image {
                self.photoImageView.contentMode = .scaleAspectFill
                self.photoImageView.image = image
            } else {
                self.photoImageView.contentMode = .center
                self.photoImageView.tintColor = Theme.muted
                self.photoImageView.image = UIImage(systemName: "photo",
                                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 44))
            }
        }
        if animated {
            UIView.transition(with: photoImageView, duration: 0.45, options: .transitionCrossDissolve,
                              animations: update, completion: nil)
        } else {
            update()
        }
        photoButton.setTitle(image == nil ? "Add My Photo" : "Change My Photo", for: .normal)
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

    /// Hands off to Apple Maps with walking or driving directions, matching the Vacant Planner's mode.
    @objc private func directionsTapped() {
        guard let spot = spot else { return }
        Theme.hapticLight()
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = spot.name
        let mode = travelMode == .walk ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }

    /// System share sheet with a ready-to-send invite.
    @objc private func shareTapped(_ sender: UIBarButtonItem) {
        guard let spot = spot else { return }
        Theme.hapticLight()
        let name = spot.name ?? "this spot"
        let address = spot.address ?? "near FEU Diliman"
        let text = "Let's go to \(name)! 📍 \(address) — via Kain Spot"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = sender
        present(activity, animated: true)
    }

    /// Saves the picked image under the spot's fixed file name, then shows it.
    private func savePickedImage(_ image: UIImage) {
        guard let fileName = photoFileName else { return }
        do {
            _ = try photoStore.save(image, named: fileName)
            showPhoto(image, animated: true)
            Theme.hapticSuccess()
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

    /// Orange marker with the spot's emoji, green 🎓 marker for campus, default blue dot for the user.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let point = annotation as? MKPointAnnotation else { return nil }
        let identifier = "KainSpotPin"
        let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: point, reuseIdentifier: identifier)
        marker.annotation = point
        marker.canShowCallout = true
        // glyphImage would win over glyphText, so clear it and show the emoji instead.
        marker.glyphImage = nil
        if point === feuAnnotation {
            marker.markerTintColor = Theme.success
            marker.glyphText = "🎓"
        } else {
            marker.markerTintColor = Theme.primary
            marker.glyphText = spot.map { KainNavigator.emoji(for: $0) } ?? "📍"
        }
        return marker
    }

    /// Dashed orange line from campus to the spot.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = Theme.primary
        renderer.lineWidth = 4
        renderer.lineDashPattern = [8, 6]
        renderer.lineCap = .round
        return renderer
    }
}
