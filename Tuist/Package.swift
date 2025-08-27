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
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.5.1")
    ]
)


