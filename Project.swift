import ProjectDescription

let name = "Calycal-Tuist"

let project = Project(
    name: name,
    settings: .settings(
        configurations: [
            .debug(name: "Debug", xcconfig: "./xcconfigs/Project.xcconfig"),
            .release(name: "Release", xcconfig: "./xcconfigs/Project.xcconfig")
        ]
    ),
    targets: [
        .target(
            name: "Calycal",
            destinations: .iOS,
            product: .app,
            bundleId: "stua.calcalcal",
            deploymentTargets: .iOS("17.6"),
            infoPlist: .file(path: "calcalcal/Info.plist"),
            sources: [
                "calcalcal/**",
                "calcalcal/calcalcalApp.swift",
                "calcalcal/main.swift"
            ],
            entitlements: .file(path: "calcalcal/calcalcal.entitlements"),
            dependencies: [
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/Calycal.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/Calycal.xcconfig")
                ]
            )
        ),
        .target(
            name: "CalycalTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "stua.calcalcalTests",
            infoPlist: .default,
            sources: ["calcalcalTests/**"],
            dependencies: [
                .target(name: "Calycal")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/CalycalTests.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/CalycalTests.xcconfig")
                ]
            )
        ),
        .target(
            name: "CalycalUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "stua.calcalcalUITests",
            infoPlist: .default,
            sources: ["calcalcalUITests/**"],
            dependencies: [
                .target(name: "Calycal")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/CalycalUITests.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/CalycalUITests.xcconfig")
                ]
            )
        )
    ]
)


