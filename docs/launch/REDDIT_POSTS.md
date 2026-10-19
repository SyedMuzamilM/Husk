# Reddit posts for Husk

Prepared on 2026-10-19. The GitHub repository is currently private and has no published release. Draft 1 is usable before publication. Drafts 2 and 3 assume the updated source has been published and the link opens when signed out. Nothing has been posted.

## 1. r/SideProject feedback post, usable now

Title: I'm building a native Mac storage tool that shows the exact paths before cleanup

Attach: `images/01-storage-map-light.png`, then `images/03-review-paths.png`.

Body:

I'm building Husk, a native Mac app for understanding what's taking up disk space and reviewing what to remove.

The storage map shows folders alongside cleanup candidates. You can inspect paths and risk labels, choose items, and review the selection before anything moves to Trash. The app also has app removal, AI storage inspection, and a process view.

One decision I've made: AI sessions, model weights, and working copies stay inspection-only. A large folder isn't enough evidence that it should go.

Scans run locally, with no telemetry or network client. The screenshots are from the real app using example data. The displayed sizes aren't a claim about space it has saved.

It's experimental. The repository is still private, and there's no signed public download yet. I'm preparing the code under source-available terms that allow private builds and modifications but restrict redistribution.

I'm looking for feedback on the review flow. What would you want to see before trusting an app to move files to Trash?

## 2. r/SideProject source launch, after publication

Title: I built Husk, a native Mac storage tool with a treemap and reviewed cleanup

Attach: `images/01-storage-map-light.png`, `images/03-review-paths.png`, then `images/02-storage-map-dark.png`.

Body:

I've published the source for Husk, a Mac app I've been building in Swift and SwiftUI.

The main view puts a storage map and cleanup candidates together. You can browse folders, inspect exact paths and risks, then review selected items before moving them to Trash. There are also views for app removal, AI storage, and system processes.

AI sessions, model weights, and working copies stay inspection-only. Cleanup is limited to supported locations with explicit selection and review. Husk doesn't automatically delete files or empty Trash. Moving something to Trash usually won't free the space until you empty it.

The current app runs locally without telemetry or a network client. These screenshots use example data.

Source and build instructions: https://github.com/SyedMuzamilM/Husk

It's experimental and currently a build-it-yourself project, with no signed public release. The declared minimum is macOS 14, with Xcode 26.2 and Swift 6.2 to build; the minimum OS and Intel runtime still need verification.

The license is source-available: private use, builds, and modifications are allowed; general redistribution is restricted. Earlier MIT grants and third-party rights remain intact. It isn't OSI open source.

I'd like feedback on the storage map and the review step. Is the path and risk information enough to make a decision, or is something missing?

## 3. r/macapps monthly promotion megathread, after publication

Use this as a comment in the current monthly promotion megathread unless you qualify for the subreddit's main feed. It is not a main-feed template. Attach `images/01-storage-map-light.png` if the thread supports image comments; otherwise the repository README contains the screenshot. Do not use an open-source flair or an `[OS]` title prefix.

Comment:

I'm the developer of Husk, an experimental native Mac app for reviewing storage and cleanup candidates.

It combines a folder treemap with exact paths, risk labels, and a review step before selected items move to Trash. It also includes app removal, AI storage inspection, and system monitoring. AI sessions, model weights, and working copies remain inspection-only. It doesn't automatically delete files or empty Trash.

The app runs locally with no telemetry or network client. There is no signed public download yet; the source and build instructions are here: https://github.com/SyedMuzamilM/Husk

Private builds and use have no license fee. The license is source-available with redistribution restrictions, subject to prior MIT and third-party rights. It isn't OSI open source. The declared minimum is macOS 14; building requires Xcode 26.2 and Swift 6.2. Minimum-OS and Intel runtime testing remain open.

Screenshots show example data. I'd appreciate feedback on whether the path review is clear enough before cleanup.

## Images and captions

All three images are 1600 x 1200 PNGs. They use existing native app captures with example data. No UI or results were generated, and the numbers are not measured savings.

- [Storage map, light](images/01-storage-map-light.png). Caption: "Husk's storage map and cleanup recommendations. Real app UI with example data." Alt: "A light macOS window with a folder treemap, available capacity, and separate cache and review recommendations."
- [Storage map, dark](images/02-storage-map-dark.png). Caption: "The same storage view in dark appearance. Example data; sizes are estimates." Alt: "Husk in dark appearance, showing the folder treemap and unselected cleanup candidates."
- [Path review detail](images/03-review-paths.png). Caption: "Select candidates and review their paths before moving them to Trash. Example data." Alt: "An enlarged crop of Husk's recommendations panel beside an explanation of inspecting, selecting, and reviewing items."

The images deliberately omit a public download claim, so they can accompany prelaunch feedback. Use the first image as the cover. The third is a closer crop of the real recommendations panel, not a screenshot of the final confirmation dialog.

Sources: [light capture](../screenshots/storage-map-light.png) and [dark capture](../screenshots/storage-map-dark.png), already tracked in the repository. Regenerate on macOS with Pillow installed:

```sh
python3 docs/launch/generate-images.py
```

## Posting notes

- Start with draft 1 while the repo is private. Use the launch drafts only after the new license and docs are published and the repository opens signed out. Remove or update the no-release statement if an official signed release becomes available.
- r/macapps currently requires 10 local karma, limits developer promotion to once per 30 days, and uses trust/transparency qualification plus its PCP template for main-feed promotion. Its rules also link to a post-approval process. The megathread draft avoids assuming you qualify for the main feed. Check the current thread instructions before using it.
- r/SideProject's rules endpoint returned no additional subreddit rules when checked. Check its sidebar and pinned threads before posting. Disclose that you're the developer, as these drafts do, and avoid posting both variants there as repeat promotion.
- Don't describe the current license as MIT or open source, advertise guaranteed reclaimed space, or present the screenshots as real cleanup results. Source publication also doesn't mean there's a signed binary download.

Rules checked on 2026-10-19: [r/macapps rules](https://www.reddit.com/r/macapps/about/rules), [main-feed qualification](https://www.reddit.com/r/macapps/comments/1ryaeex/), [post-approval instructions](https://www.reddit.com/r/macapps/comments/1smg62t/), and [r/SideProject rules](https://www.reddit.com/r/SideProject/about/rules). Licensing details are in the [project guide](../LICENSING.md).
