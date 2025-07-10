import SwiftUI

struct SettingsView: View {
    @State private var selectedLanguage = "English"
    let languages = ["English", "Chinese"]
    
    var body: some View {
        Form {
            Section(header: Text("Language")) {
                Picker("App Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang)
                    }
                }
                .pickerStyle(.segmented)
            }
            // Placeholder for other settings
            Section(header: Text("About")) {
                Text("Version 1.0.0")
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 