import SwiftUI

struct RecordingNameView: View {
    @Binding var recordingName: String
    @State private var isEditingName: Bool = false
    @State private var tempRecordingName: String = ""
    @State private var showNameSavedAlert: Bool = false
    let defaultName: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Recording Name")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            if isEditingName {
                HStack {
                    Spacer()
                    TextField("Enter recording name", text: $tempRecordingName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 220)
                    Button(action: {
                        recordingName = tempRecordingName.isEmpty ? defaultName : tempRecordingName
                        isEditingName = false
                        showNameSavedAlert = true
                    }) {
                        Text("Confirm")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Spacer()
                    Text(recordingName.isEmpty ? "(No name)" : recordingName)
                        .foregroundColor(.blue)
                        .font(.title3)
                        .bold()
                    Button(action: {
                        tempRecordingName = recordingName
                        isEditingName = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Edit")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
            }
        }
        .alert(isPresented: $showNameSavedAlert) {
            Alert(title: Text("Name Updated"), message: Text("Recording name has been updated."), dismissButton: .default(Text("OK")))
        }
    }
}

struct RecordingNameView_Previews: PreviewProvider {
    @State static var name = ""
    static var previews: some View {
        RecordingNameView(recordingName: $name, defaultName: "2024-06-09 15:30")
    }
} 