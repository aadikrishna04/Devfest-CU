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
                                .foregroundColor(.primary)
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
                // Default to user location, or Columbia University if unavailable
                let center = viewModel.userLocation ?? CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9626)
                position = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))
                Task { await viewModel.fetchData() }
            }

            VStack(spacing: 0) {
                searchBar
                filterToggles
                Spacer()
                myLocationButton
                legend
                if let item = selectedItem {
                    selectedItemCard(item)
                }
            }
        }
        .background(MedkitTheme.sessionBackground)
        .navigationTitle("AEDs, Hospitals & Pharmacies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task { await viewModel.fetchData() }
                }) {
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

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search AEDs, hospitals, or pharmacies...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var filterToggles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Toggle(isOn: $viewModel.showAeds) {
                    Label("AEDs", systemImage: "heart.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .tint(MedkitTheme.accent)

                Toggle(isOn: $viewModel.showHospitals) {
                    Label("Hospitals", systemImage: "cross.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .tint(.blue)

                Toggle(isOn: $viewModel.showPharmacies) {
                    Label("Pharmacies", systemImage: "pills.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .tint(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var myLocationButton: some View {
        Button(action: {
            if let coord = viewModel.userLocation {
                withAnimation(.easeInOut(duration: 0.3)) {
                    position = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                    ))
                }
            } else {
                // No location: center on Columbia University
                withAnimation(.easeInOut(duration: 0.3)) {
                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9626),
                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                    ))
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                Text(viewModel.userLocation != nil ? "My Location" : "Columbia University")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MedkitTheme.accent)
            .clipShape(Capsule())
        }
        .padding(.bottom, 12)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(MedkitTheme.accent)
                Text("AED")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            HStack(spacing: 6) {
                Image(systemName: "cross.fill")
                    .foregroundColor(.blue)
                Text("Hospital")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            HStack(spacing: 6) {
                Image(systemName: "pills.fill")
                    .foregroundColor(.green)
                Text("Pharmacy")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 24)
    }

    private func selectedItemCard(_ item: MapLocationItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForType(item.type))
                    .foregroundColor(colorForType(item.type))
                Text(item.title)
                    .font(.headline)
                Spacer()
                Button(action: { selectedItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            if let sub = item.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(action: { openInMaps(item) }) {
                Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MedkitTheme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

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
                .shadow(radius: 4)
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
