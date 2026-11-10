# Kain Spot

Kain Spot is an iPhone app (UIKit, Swift 5, iOS 16+) that helps FEU Diliman students find trendy food spots near campus.
Final project for FEU Institute of Technology, IT0093 Mobile Application Development 2.

## What it does
- **Home**: welcome screen with your nickname and quick buttons.
- **Plan your kain**: set a nickname, price range (₱ / ₱₱ / ₱₱₱), "Trending only", and how far you are willing to go.
- **Spot list**: food spots loaded from an online JSON file, saved with Core Data so they still show offline. Pull down to refresh.
- **Spot detail**: map of the spot and FEU Diliman, distance from campus and from you, and your own photo of the place.
- **My Food Gallery**: a grid of your food pictures, picked from the photo library and saved on the phone.

## Run it on a school Mac
1. Open the project folder and double-click **`KainSpot.xcodeproj`**.
2. At the top of Xcode, next to the **KainSpot** scheme, choose an iPhone simulator (for example **iPhone 16 Pro**).
3. Press **Cmd+R** to build and run the app.
4. Press **Cmd+U** to run all unit tests and the UI demo test.

No accounts, keys or extra packages are needed.

> If `KainSpot.xcodeproj` is missing, generate it with XcodeGen: `brew install xcodegen` then `xcodegen generate` in this folder.

## Project layout (MVC)
```
KainSpot/
  App/          AppDelegate, SceneDelegate, Info.plist
  Model/        Core Data model, SpotDTO, SpotFilter, PriceLevel
  View/         Main.storyboard, LaunchScreen.storyboard, cells, Theme
  Controller/   Home, Preferences, Spot List, Spot Detail, Gallery screens
  Services/     CoreDataStack, SpotSyncService, PhotoStore, LocationService, DistanceCalculator, UserPrefs
  Resources/    spots.json (offline copy), Assets.xcassets
KainSpotTests/    unit tests
KainSpotUITests/  UI demo walkthrough test
data/spots.json   the published online data file
```

## Continuous integration
`.github/workflows/ios.yml` builds the app on a GitHub-hosted Mac, runs the unit tests, records the UI demo walkthrough to `demo.mp4`,
and takes Home screenshots on an iPhone SE and an iPhone 16 Pro. Everything is uploaded as the **kainspot-output** artifact.
