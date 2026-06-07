import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("MQTT Explorer")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A native macOS MQTT topic explorer.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Home Computer Group")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)
            
            Text("App Icon: Hilmy Abiyyu A.")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("Licensed under GNU AGPL v3.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 320, height: 340)
    }
}
