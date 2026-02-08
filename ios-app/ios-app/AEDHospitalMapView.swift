import MapKit
import SwiftUI

struct AEDHospitalMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedItem: MapLocationItem?

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: $selectedItem) {
                UserAnnotation()

                ForEach(viewModel.allFilteredLocations) { item in
                    Annotation("", coordinate: item.coordinate) {
                        VStack(spacing: 4) {
                            MapMarkerView(type: item.type)
                            Text(item.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(MedkitTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tag(item)
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                viewModel.requestLocation()
                let center = viewModel.userLocation ?? CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9626)
                position = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))
                Task { await viewModel.fetchData() }
            }

            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Filter chips
                filterChips
                    .padding(.top, 8)

                Spacer()

                // My location button
                myLocationButton
                    .padding(.bottom, 8)

                // Legend
                legend
                    .padding(.bottom, 12)

                // Selected item card
                if let item = selectedItem {
                    selectedItemCard(item)
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Nearby Resources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(MedkitTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { Task { await viewModel.fetchData() } }) {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(MedkitTheme.accent)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .alert("Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MedkitTheme.textSecondary)
            TextField("Search locations...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MedkitTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(MedkitTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "AEDs", icon: "heart.fill", color: MedkitTheme.accent, isOn: $viewModel.showAeds)
                filterChip(label: "Hospitals", icon: "cross.fill", color: .blue, isOn: $viewModel.showHospitals)
                filterChip(label: "Pharmacies", icon: "pills.fill", color: .green, isOn: $viewModel.showPharmacies)
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isOn.wrappedValue ? .white : MedkitTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn.wrappedValue ? color : MedkitTheme.cardBackground)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        }
    }

    // MARK: - My Location

    private var myLocationButton: some View {
        Button(action: {
            let coord = viewModel.userLocation ?? CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9626)
            withAnimation(.easeInOut(duration: 0.3)) {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text(viewModel.userLocation != nil ? "My Location" : "Columbia University")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MedkitTheme.accent)
            .clipShape(Capsule())
            .shadow(color: MedkitTheme.accent.opacity(0.3), radius: 8, y: 3)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(icon: "heart.fill", label: "AED", color: MedkitTheme.accent)
            legendItem(icon: "cross.fill", label: "Hospital", color: .blue)
            legendItem(icon: "pills.fill", label: "Pharmacy", color: .green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MedkitTheme.cardBackground.opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func legendItem(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MedkitTheme.textPrimary)
        }
    }

    // MARK: - Selected Item Card

    private func selectedItemCard(_ item: MapLocationItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconForType(item.type))
                    .foregroundColor(colorForType(item.type))
                    .font(.title3)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(MedkitTheme.textPrimary)
                Spacer()
                Button(action: { selectedItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MedkitTheme.textSecondary)
                }
            }
            if let sub = item.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(MedkitTheme.textSecondary)
            }
            Button(action: { openInMaps(item) }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.caption)
                    Text("Get Directions")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MedkitTheme.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(MedkitTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func iconForType(_ type: MapLocationType) -> String {
        switch type {
        case .aed: return "heart.fill"
        case .hospital: return "cross.fill"
        case .pharmacy: return "pills.fill"
        }
    }

    private func colorForType(_ type: MapLocationType) -> Color {
        switch type {
        case .aed: return MedkitTheme.accent
        case .hospital: return .blue
        case .pharmacy: return .green
        }
    }

    private func openInMaps(_ item: MapLocationItem) {
        let placemark = MKPlacemark(coordinate: item.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

struct MapMarkerView: View {
    let type: MapLocationType

    private var fillColor: Color {
        switch type {
        case .aed: return MedkitTheme.accent
        case .hospital: return .blue
        case .pharmacy: return .green
        }
    }

    private var iconName: String {
        switch type {
        case .aed: return "heart.fill"
        case .hospital: return "cross.fill"
        case .pharmacy: return "pills.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 28, height: 28)
                .shadow(color: fillColor.opacity(0.3), radius: 4, y: 2)
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
