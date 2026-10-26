import SwiftUI

/// Mods and Skins: header as on Settings, nothing below yet.
struct ComingSoonScreen: View {
    let title: String

    var body: some View {
        VStack {
            PageHeader(eyebrow: title, title: title, subtitle: "Coming soon.")
                .padding(.top, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
