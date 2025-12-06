// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "Calycal",
    dependencies: [
        // Google Sign-In SDK for iOS
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
    ]
)


