import Foundation

/// Fixed cleanup locations and their review policies. Discovery supplies existing sibling entries.
enum CleanTargetCatalog {
    static func targets(home: String) -> [CleanTarget] {
        let lib = (home as NSString).appendingPathComponent("Library")
        var list: [CleanTarget] = []

        func add(
            _ categoryID: String,
            _ categoryName: String,
            _ image: String,
            _ name: String,
            _ path: String,
            safety: SafetyLabel? = nil,
            reason: String? = nil
        ) {
            list.append(
                CleanTarget(
                    categoryID: categoryID,
                    categoryName: categoryName,
                    systemImage: image,
                    name: name,
                    path: path,
                    safetyOverride: safety,
                    reasonOverride: reason
                )
            )
        }

        let browsers: [(String, String)] = [
            ("Safari", (lib as NSString).appendingPathComponent("Caches/com.apple.Safari")),
            ("Chrome", (home as NSString).appendingPathComponent("Library/Caches/Google/Chrome")),
            ("Firefox", (home as NSString).appendingPathComponent("Library/Caches/Firefox")),
            ("Arc", (home as NSString).appendingPathComponent("Library/Caches/Company.TheBrowserCompany.Arc")),
            ("Arc (legacy)", (home as NSString).appendingPathComponent("Library/Caches/Arc")),
            ("Edge", (home as NSString).appendingPathComponent("Library/Caches/com.microsoft.edgemac")),
            ("Brave", (home as NSString).appendingPathComponent("Library/Caches/BraveSoftware"))
        ]
        for (name, path) in browsers {
            add(
                "browsers", "Browsers", "globe", name, path,
                safety: .safe,
                reason: "Browser cache — recreated automatically"
            )
        }

        add(
            "developer", "Developer", "hammer", "Xcode DerivedData",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            safety: .review,
            reason: "Build intermediates — recreated on next compile"
        )
        add(
            "developer", "Developer", "hammer", "Xcode Archives",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/Archives"),
            safety: .caution,
            reason: "May contain archived builds you want to keep"
        )
        add(
            "developer", "Developer", "hammer", "iOS DeviceSupport",
            (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            safety: .review,
            reason: "Device symbols — re-downloaded when needed"
        )
        add(
            "developer", "Developer", "hammer", "Simulator Caches",
            (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            safety: .safe,
            reason: "Simulator caches — regenerable"
        )

        // Package-manager download caches and review-only stores.
        add("package-managers", "Package Managers", "shippingbox", "Homebrew Cache",
            (home as NSString).appendingPathComponent("Library/Caches/Homebrew"),
            safety: .safe, reason: "Homebrew download cache")
        add("package-managers", "Package Managers", "shippingbox", "npm _cacache",
            (home as NSString).appendingPathComponent(".npm/_cacache"),
            safety: .safe, reason: "npm package cache")
        add("package-managers", "Package Managers", "shippingbox", "npm _npx",
            (home as NSString).appendingPathComponent(".npm/_npx"),
            safety: .safe, reason: "npx temporary package cache")
        add("package-managers", "Package Managers", "shippingbox", "pnpm store",
            (home as NSString).appendingPathComponent("Library/pnpm/store"),
            safety: .review, reason: "pnpm content-addressable store")
        add("package-managers", "Package Managers", "shippingbox", "Yarn cache",
            (home as NSString).appendingPathComponent("Library/Caches/Yarn"),
            safety: .safe, reason: "Yarn package cache")
        add("package-managers", "Package Managers", "shippingbox", "Bun install cache",
            (home as NSString).appendingPathComponent(".bun/install/cache"),
            safety: .safe, reason: "Bun package install cache")
        add("package-managers", "Package Managers", "shippingbox", "pip Cache",
            (home as NSString).appendingPathComponent("Library/Caches/pip"),
            safety: .safe, reason: "Python pip cache")
        add("package-managers", "Package Managers", "shippingbox", "uv cache",
            (home as NSString).appendingPathComponent(".cache/uv"),
            safety: .safe, reason: "uv Python package cache")
        add("package-managers", "Package Managers", "shippingbox", "Cargo registry cache",
            (home as NSString).appendingPathComponent(".cargo/registry/cache"),
            safety: .safe, reason: "Rust crate download cache")
        add("package-managers", "Package Managers", "shippingbox", "Go build cache",
            (home as NSString).appendingPathComponent("Library/Caches/go-build"),
            safety: .safe, reason: "Go compiler cache")
        add("package-managers", "Package Managers", "shippingbox", "Gradle caches",
            (home as NSString).appendingPathComponent(".gradle/caches"),
            safety: .review, reason: "Gradle dependency caches")
        add("package-managers", "Package Managers", "shippingbox", "CocoaPods cache",
            (home as NSString).appendingPathComponent("Library/Caches/CocoaPods"),
            safety: .safe, reason: "CocoaPods download cache")
        add("package-managers", "Package Managers", "shippingbox", "Turbo cache",
            (home as NSString).appendingPathComponent(".turbo/cache"),
            safety: .safe, reason: "Turborepo remote/local cache")
        add("package-managers", "Package Managers", "shippingbox", "Vite cache",
            (home as NSString).appendingPathComponent(".cache/vite"),
            safety: .safe, reason: "Vite bundler cache")
        add("package-managers", "Package Managers", "shippingbox", "Webpack cache",
            (home as NSString).appendingPathComponent(".cache/webpack"),
            safety: .safe, reason: "Webpack cache")

        add("package-managers", "Package Managers", "shippingbox", "Pub Cache",
            (home as NSString).appendingPathComponent(".pub-cache"),
            safety: .review, reason: "Flutter/Dart dependency cache")
        add("package-managers", "Package Managers", "shippingbox", "Deno Cache",
            (home as NSString).appendingPathComponent("Library/Caches/deno"),
            safety: .safe, reason: "Deno modules and compiler cache")
        add("package-managers", "Package Managers", "shippingbox", "Swift PM Cache",
            (home as NSString).appendingPathComponent("Library/Caches/org.swift.swiftpm"),
            safety: .safe, reason: "Swift Package Manager repositories cache")
        add("package-managers", "Package Managers", "shippingbox", "Cypress Cache",
            (home as NSString).appendingPathComponent("Library/Caches/Cypress"),
            safety: .review, reason: "Cypress binary installations")
        add("package-managers", "Package Managers", "shippingbox", "Cargo Registry Index",
            (home as NSString).appendingPathComponent(".cargo/registry/index"),
            safety: .safe, reason: "Rust crate registry index")
        add("package-managers", "Package Managers", "shippingbox", "Cargo Git DB",
            (home as NSString).appendingPathComponent(".cargo/git/db"),
            safety: .review, reason: "Rust git dependencies database")
        add("package-managers", "Package Managers", "shippingbox", "Poetry Cache",
            (home as NSString).appendingPathComponent("Library/Caches/pypoetry"),
            safety: .review, reason: "Poetry virtual environments and package cache")
        add("package-managers", "Package Managers", "shippingbox", "pip Cache (Home)",
            (home as NSString).appendingPathComponent(".cache/pip"),
            safety: .safe, reason: "Python pip download cache")

        let support = (lib as NSString).appendingPathComponent("Application Support")
        // Shared explicit AI rules; sessions, models, versions and worktrees never become cache targets.
        for rule in AIStorageCatalog.rules where rule.removable {
            add("ai-agents", "AI Caches", "cpu", rule.tool + " · " + (rule.relativePath as NSString).lastPathComponent,
                rule.path(home: home), safety: .review, reason: rule.detail)
        }

        add("ai-agents", "AI Agents", "cpu", "Ollama App Cache",
            (home as NSString).appendingPathComponent("Library/Caches/com.electron.ollama"),
            safety: .safe, reason: "Ollama Desktop client cache")
        add("ai-agents", "AI Agents", "cpu", "LM Studio App Cache",
            (home as NSString).appendingPathComponent("Library/Caches/lm-studio"),
            safety: .safe, reason: "LM Studio Desktop client cache")

        // IDEs & Editor system caches (keep user preferences and configurations intact)
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "VS Code Cache",
            (support as NSString).appendingPathComponent("Code/Cache"),
            safety: .safe, reason: "VS Code Chromium cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "VS Code CachedData",
            (support as NSString).appendingPathComponent("Code/CachedData"),
            safety: .safe, reason: "VS Code cached extension data")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Zed cache",
            (home as NSString).appendingPathComponent("Library/Caches/Zed"),
            safety: .safe, reason: "Zed editor cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "JetBrains logs",
            (home as NSString).appendingPathComponent("Library/Logs/JetBrains"),
            safety: .review, reason: "JetBrains IDE logs")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "Xcode cache",
            (home as NSString).appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            safety: .safe, reason: "Xcode app cache")
        add("ide", "Editors & IDEs", "chevron.left.forwardslash.chevron.right", "JetBrains Caches",
            (home as NSString).appendingPathComponent("Library/Caches/JetBrains"),
            safety: .review, reason: "IntelliJ, PyCharm, WebStorm, CLion cache and indexing data")

        add(
            "logs", "Logs", "doc.text", "Diagnostic Reports",
            (lib as NSString).appendingPathComponent("Logs/DiagnosticReports"),
            safety: .review, reason: "Crash and diagnostic reports"
        )

        return list
    }
}
