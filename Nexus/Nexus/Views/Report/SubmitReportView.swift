import SwiftUI
import PhotosUI

struct SubmitReportView: View {
    @State private var reportText = ""
    @State private var selectedCategory: NexusEvent.EventCategory = .other
    @State private var locationText = "Current Location"
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Report text
                Section("What's happening?") {
                    TextEditor(text: $reportText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if reportText.isEmpty {
                                Text("Describe what you're seeing...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Category
                Section("Category") {
                    Picker("Event type", selection: $selectedCategory) {
                        ForEach(NexusEvent.EventCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Media
                Section("Media") {
                    PhotosPicker(selection: $selectedPhotos,
                                 maxSelectionCount: 5,
                                 matching: .any(of: [.images, .videos])) {
                        Label(selectedPhotos.isEmpty ? "Add photos or video" : "\(selectedPhotos.count) item(s) selected",
                              systemImage: "camera.fill")
                    }
                }

                // Location
                Section("Location") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        Text(locationText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Submit
                Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Submit Report", systemImage: "paperplane.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(reportText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Report")
            .alert("Report Submitted", isPresented: $showConfirmation) {
                Button("OK") {
                    reportText = ""
                    selectedPhotos = []
                    selectedCategory = .other
                }
            } message: {
                Text("Your report has been submitted and will be linked to a nearby Nexus event if one exists.")
            }
        }
    }
}

#Preview {
    SubmitReportView()
}
