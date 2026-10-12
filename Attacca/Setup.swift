//
//  Setup.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - One-time setup screen

/// Explains the one-time iCloud Drive grant: why it's required (Apple privacy rules),
/// exactly what to tap, and that iCloud Drive itself is the choice that works.
struct SetupView: View {
    /// true on first launch; false when re-opened from the settings button.
    let isFirstRun: Bool
    let onContinue: () -> Void

    /// e.g. "Attacca 1.0.0 (build 42)"
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Attacca \(version) (build \(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text(isFirstRun ? "One-time setup" : "Change iCloud access")
                        .font(.largeTitle.bold())
                    Group {
                        if isFirstRun {
                            Text("Attacca needs permission to read your music in iCloud Drive. You only do this **once**. After that, Attacca opens straight to your music every time.")
                        } else {
                            Text("Re-grant access to iCloud Drive. Use this if Attacca was set up with a single folder, or access stopped working.")
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                // Why
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why is this needed?").font(.headline)
                        Text("Apple's iPhone privacy rules don't allow any app to look at your files on its own. You must grant access yourself, once, using Apple's file picker.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Steps
                VStack(alignment: .leading, spacing: 14) {
                    Text("On the next screen").font(.headline)
                    StepRow(number: 1, text: "Under **Locations**, tap **iCloud Drive**.")
                    StepRow(number: 2, text: "**Don't open any folder.** Stay at the top level of iCloud Drive.")
                    StepRow(number: 3, text: "Tap **Open** in the top-right corner.")
                }

                // The only option that works
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("**Select iCloud Drive itself.** This is the only choice that lets Attacca browse all of your music folders. Picking a folder inside it limits Attacca to that one folder.")
                        .font(.subheadline)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                // Action
                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label("Continue to iCloud Drive", systemImage: "icloud")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if isFirstRun {
                        Text("You won't see this screen again.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Self.versionString)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))
            Text(text)
        }
    }
}

// MARK: - Picker with validation

/// Presents Apple's folder picker and checks the choice. If the user picked a folder
/// inside iCloud Drive instead of iCloud Drive itself, explain and offer to pick again.
struct ICloudPicker: ViewModifier {
    @Binding var isPresented: Bool
    var onGranted: () -> Void = {}

    @Environment(FolderAccess.self) private var access
    @State private var pending: URL?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                if FolderAccess.isICloudDriveRoot(url) {
                    access.set(url)
                    onGranted()
                } else {
                    pending = url
                }
            }
            .alert("That's a folder, not iCloud Drive",
                   isPresented: Binding(get: { pending != nil },
                                        set: { if !$0 { pending = nil } }),
                   presenting: pending) { url in
                Button("Pick iCloud Drive Instead") {
                    pending = nil
                    // Let the alert finish dismissing before showing the picker again.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isPresented = true }
                }
                Button("Use “\(url.lastPathComponent)” Only") {
                    access.set(url)
                    pending = nil
                    onGranted()
                }
            } message: { url in
                Text("You picked “\(url.lastPathComponent)”. Attacca will only see that folder and its subfolders. To browse all your music, pick iCloud Drive itself at the top level, then tap Open.")
            }
    }
}

extension View {
    func iCloudPicker(isPresented: Binding<Bool>, onGranted: @escaping () -> Void = {}) -> some View {
        modifier(ICloudPicker(isPresented: isPresented, onGranted: onGranted))
    }
}
