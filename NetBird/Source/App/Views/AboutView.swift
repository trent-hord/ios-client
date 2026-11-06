//
//  AboutView.swift
//  NetBirdiOS
//
//  Created by Pascal Fischer on 01.08.23.
//
//  Modified for Trentfinity VPN on 2026-11-05: branding and project attribution.

import SwiftUI
import NetBirdSDK

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "infinity")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.accentColor)
                            Text("Trentfinity VPN")
                                .font(.title3.weight(.semibold))
                        }
                        VStack(spacing: 4) {
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundColor(Color("TextSecondary"))
                            Text("NetBird core \(goVersion)")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Independent project") {
                Text("Trentfinity VPN is an independently maintained NetBird client. It is not affiliated with or endorsed by NetBird GmbH.")
                    .foregroundColor(Color("TextSecondary"))
            }

            Section("Project") {
                projectLink("Source & updates", destination: GlobalConstants.projectSourceURL)
                projectLink("Support & issues", destination: GlobalConstants.projectSupportURL)
                projectLink("GNU GPLv3 license", destination: GlobalConstants.projectLicenseURL)
            }

            Section("Open-source credits") {
                Text("Based on the NetBird Apple client. Upstream work by NetBird GmbH and contributors; fork changes by Trentfinity VPN contributors.")
                Text("This app is distributed under the GNU General Public License, version 3. Its source code and license are available through the links above.")
            }
            .font(.footnote)
            .foregroundColor(Color("TextSecondary"))
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func projectLink(_ title: String, destination: String) -> some View {
        if let url = URL(string: destination) {
            Link(destination: url) {
                HStack {
                    Text(title)
                        .foregroundColor(Color("TextPrimary"))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(Color("TextSecondary"))
                        .font(.system(size: 14))
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// Version of the Go client baked into NetBirdSDK.xcframework at compile time.
    private var goVersion: String {
        let version = NetBirdSDKGoClientVersion()
        return version.isEmpty ? "unknown" : version
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
