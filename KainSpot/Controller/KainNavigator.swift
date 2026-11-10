//
//  KainNavigator.swift
//  KainSpot — Controller layer
//  Small shared helpers the new screens use: fetch every Spot, open the storyboard detail screen
//  from code, and the per-spot display text (emoji, travel time, leave-by) so cells and cards match.
//  Feature: UI upgrade (Roulette, Ask Kain Spot and the list all open SpotDetail the same way — DRY).
//

import UIKit
import CoreData

/// Stateless helpers; prefixed "Kain" so the name never collides with other services.
enum KainNavigator {

    /// Vacant used when a screen has no filter (Ask, Roulette from Ask): one class hour.
    static let defaultVacantMinutes = 60

    /// Every stored spot, best rated first. Errors are logged and give an empty list (never a crash).
    static func fetchAllSpots(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) -> [Spot] {
        let request = NSFetchRequest<Spot>(entityName: "Spot")
        request.sortDescriptors = [NSSortDescriptor(key: "rating", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            print("KainNavigator fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Builds the storyboard SpotDetailViewController (identifier "SpotDetailViewController").
    /// Programmatic screens have no `storyboard` property, so Main.storyboard is loaded by name.
    static func makeDetail(for spot: Spot, vacantMinutes: Int) -> SpotDetailViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detail = storyboard.instantiateViewController(withIdentifier: "SpotDetailViewController")
                as? SpotDetailViewController else { return nil }
        detail.spot = spot
        detail.vacantMinutes = vacantMinutes
        return detail
    }

    /// The spot's own emoji, else its kind's emoji, else a pin.
    static func emoji(for spot: Spot) -> String {
        if let emoji = spot.emoji, !emoji.isEmpty, emoji != "📍" {
            return emoji
        }
        return kind(of: spot)?.emoji ?? "📍"
    }

    static func kind(of spot: Spot) -> SpotKind? {
        spot.kind.flatMap { SpotKind(rawValue: $0.lowercased()) }
    }

    /// "~₱150" when we know the average spend, "Free" for ₱0 activities, otherwise the ₱ band.
    static func priceText(for spot: Spot) -> String {
        if spot.avgSpend > 0 { return "~₱\(spot.avgSpend)" }
        if kind(of: spot) == .galaw || kind(of: spot) == .gala, spot.priceLevel <= 1 { return "Free" }
        return PriceLevel.from(spot.priceLevel).symbol
    }

    /// Distance from FEU Diliman in km.
    static func distanceKm(to spot: Spot) -> Double {
        DistanceCalculator.kilometers(from: DistanceCalculator.feuDiliman,
                                      to: Coordinate(latitude: spot.latitude, longitude: spot.longitude))
    }

    /// Vacant plan from campus to this spot.
    static func plan(for spot: Spot, vacantMinutes: Int, now: Date = Date()) -> VacantPlan {
        VacantPlanner.plan(distanceKm: distanceKm(to: spot),
                           stayMinutes: Int(spot.stayMinutes),
                           vacantMinutes: vacantMinutes,
                           now: now)
    }

    /// "🚶 8 min" / "🛺 15 min".
    static func travelText(_ plan: VacantPlan) -> String {
        "\(plan.mode.emoji) \(plan.travelMinutesOneWay) min"
    }

    /// "Leave by 2:40 PM" when it fits, otherwise the gentle "Too far for this vacant".
    static func leaveText(_ plan: VacantPlan) -> String {
        plan.fits ? plan.formattedLeaveBy : "Too far for this vacant"
    }

    /// Wraps a vertical stack of views in a scrolling page, used by the programmatic screens.
    static func makeScrollingPage(in view: UIView, spacing: CGFloat = 14) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill
        view.addSubview(stack)
        Theme.embedInScrollView(stack, in: view, centered: false, horizontalInset: 20, verticalInset: 20)
        return stack
    }
}
