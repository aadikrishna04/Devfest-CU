import Combine
import CoreLocation
import Foundation
import MapKit

// MARK: - Map Location Models

enum MapLocationType: String, Identifiable {
    case aed
    case hospital
    case pharmacy

    var id: String { rawValue }
}

struct MapLocationItem: Identifiable, Hashable {
    let id: String
    let type: MapLocationType
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MapLocationItem, rhs: MapLocationItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Map View Model

@MainActor
class MapViewModel: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var aedLocations: [MapLocationItem] = []
    @Published var hospitalLocations: [MapLocationItem] = []
    @Published var pharmacyLocations: [MapLocationItem] = []
    @Published var searchText: String = ""
    @Published var filteredAeds: [MapLocationItem] = []
    @Published var filteredHospitals: [MapLocationItem] = []
    @Published var filteredPharmacies: [MapLocationItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showAeds: Bool = true
    @Published var showHospitals: Bool = true
    @Published var showPharmacies: Bool = true

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    static let nycAEDAPIs = [
        "https://data.cityofnewyork.us/resource/2ync-kihj.json",
        "https://data.cityofnewyork.us/resource/2er2-jqsx.json",
        "https://data.cityofnewyork.us/resource/duz4-2gn9.json"
    ]
    static let openDataSoftHospitals = "https://discovery.opendatasoft.com/api/explore/v2.1/catalog/datasets/us-hospitals/records"
    static let overpassAPI = "https://overpass-api.de/api/interpreter"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        Publishers.CombineLatest4($searchText, $aedLocations, $hospitalLocations, $pharmacyLocations)
            .combineLatest(Publishers.CombineLatest3($showAeds, $showHospitals, $showPharmacies))
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] data, showFlags in
                let (search, aeds, hospitals, pharmacies) = data
                let (showAeds, showHospitals, showPharmacies) = showFlags
                self?.applyFilter(search: search, aeds: aeds, hospitals: hospitals, pharmacies: pharmacies, showAeds: showAeds, showHospitals: showHospitals, showPharmacies: showPharmacies)
            }
            .store(in: &cancellables)
    }

    var allFilteredLocations: [MapLocationItem] {
        var items: [MapLocationItem] = []
        if showAeds { items.append(contentsOf: filteredAeds) }
        if showHospitals { items.append(contentsOf: filteredHospitals) }
        if showPharmacies { items.append(contentsOf: filteredPharmacies) }
        return items
    }

    static let columbiaUniversity = CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9626)

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func fetchData() async {
        isLoading = true
        errorMessage = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchAEDs() }
            group.addTask { await self.fetchHospitals() }
            group.addTask { await self.fetchPharmacies() }
        }

        isLoading = false
    }

    private func fetchAEDs() async {
        var items: [MapLocationItem] = []

        for baseURL in Self.nycAEDAPIs {
            let urlString = "\(baseURL)?$limit=800"
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) else { continue }

                let array: [[String: Any]]
                if let arr = json as? [[String: Any]] {
                    array = arr
                } else if let obj = json as? [String: Any], let arr = obj["data"] as? [[String: Any]] {
                    array = arr
                } else {
                    continue
                }

                for dict in array {
                    var lat: Double?, lon: Double?
                    if let la = parseDouble(dict["latitude"] ?? dict["Latitude"]), let lo = parseDouble(dict["longitude"] ?? dict["Longitude"]) {
                        lat = la; lon = lo
                    } else if let loc = dict["location"] as? [String: Any],
                              let la = parseDouble(loc["latitude"] ?? loc["Latitude"]), let lo = parseDouble(loc["longitude"] ?? loc["Longitude"]) {
                        lat = la; lon = lo
                    } else if let pt = dict["the_geom"] as? [String: Any],
                              let coords = pt["coordinates"] as? [Double], coords.count >= 2 {
                        lon = coords[0]; lat = coords[1]
                    } else if let pt = dict["the_geom"] as? [String: Any],
                              let coords = pt["coordinates"] as? [Any], coords.count >= 2,
                              let lonVal = coords[0] as? Double ?? (coords[0] as? Int).map(Double.init),
                              let latVal = coords[1] as? Double ?? (coords[1] as? Int).map(Double.init) {
                        lon = lonVal; lat = latVal
                    }
                    guard let latitude = lat, let longitude = lon, (-90...90).contains(latitude), (-180...180).contains(longitude) else { continue }

                    let facility = (dict["facility_name"] as? String) ?? (dict["facilityname"] as? String) ?? (dict["Facility_Name"] as? String) ?? (dict["facilityName"] as? String) ?? (dict["name"] as? String) ?? "AED"
                    let address = (dict["street_address"] as? String) ?? (dict["streetaddress"] as? String) ?? (dict["Street_Address"] as? String) ?? (dict["address"] as? String) ?? ""
                    let id = "aed-\(latitude)-\(longitude)-\(UUID().uuidString.prefix(8))"

                    items.append(MapLocationItem(id: id, type: .aed, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: facility, subtitle: address.isEmpty ? nil : address))
                }

                if !items.isEmpty {
                    aedLocations = items
                    applyFilter(search: searchText, aeds: items, hospitals: hospitalLocations, pharmacies: pharmacyLocations, showAeds: showAeds, showHospitals: showHospitals, showPharmacies: showPharmacies)
                    return
                }
            } catch {
                continue
            }
        }

        if items.isEmpty {
            errorMessage = "Could not load AED locations. Check network connection."
        }
    }

    private func parseDouble(_ value: Any?) -> Double? {
        if let s = value as? String { return Double(s) }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }

    private static let builtInHospitals: [(String, String, Double, Double)] = [
        ("NewYork-Presbyterian / Columbia", "622 W 168th St, NYC", 40.8410, -73.9404),
        ("Mount Sinai Morningside", "1111 Amsterdam Ave, NYC", 40.80564, -73.96132),
        ("NYC Health + Hospitals Harlem", "506 Lenox Ave, NYC", 40.8125, -73.9377),
        ("Mount Sinai West", "1000 10th Ave, NYC", 40.7690, -73.9865),
        ("NewYork-Presbyterian / Weill Cornell", "525 E 68th St, NYC", 40.7645, -73.9556),
        ("Lenox Hill Hospital", "100 E 77th St, NYC", 40.7735, -73.9561),
        ("Mount Sinai Hospital", "1 Gustave L Levy Pl, NYC", 40.7905, -73.9542),
        ("NYC Health + Hospitals Bellevue", "462 1st Ave, NYC", 40.7390, -73.9754),
        ("NYU Langone Health", "550 1st Ave, NYC", 40.7428, -73.9719),
        ("Mount Sinai Beth Israel", "281 1st Ave, NYC", 40.7302, -73.9789),
        ("NYC Health + Hospitals Metropolitan", "1901 1st Ave, NYC", 40.7795, -73.9425),
        ("Mount Sinai Brooklyn", "3201 Kings Hwy, Brooklyn", 40.6165, -73.9438),
        ("NYC Health + Hospitals Elmhurst", "79-01 Broadway, Queens", 40.7403, -73.8807),
        ("Flushing Hospital", "45th Ave & Parsons Blvd, Queens", 40.7478, -73.8240),
        ("Montefiore Moses", "111 E 210th St, Bronx", 40.8735, -73.8787),
        ("St. Barnabas Hospital", "4422 3rd Ave, Bronx", 40.8470, -73.9145),
    ]

    private static let mtSinaiMorningside = MapLocationItem(
        id: "hosp-mtsinai-morningside", type: .hospital,
        coordinate: CLLocationCoordinate2D(latitude: 40.80564, longitude: -73.96132),
        title: "Mount Sinai Morningside", subtitle: "1111 Amsterdam Ave, NYC"
    )

    private func fetchHospitals() async {
        var items: [MapLocationItem] = []

        if let fetched = await fetchHospitalsFromOpenDataSoft(), !fetched.isEmpty {
            items = fetched
        } else if let fetched = await fetchHospitalsFromOverpass(), !fetched.isEmpty {
            items = fetched
        } else {
            let center = userLocation ?? Self.columbiaUniversity
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let maxDistanceMeters: Double = 60_000
            for (idx, (name, address, lat, lon)) in Self.builtInHospitals.enumerated() {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let loc = CLLocation(latitude: lat, longitude: lon)
                if centerLocation.distance(from: loc) <= maxDistanceMeters {
                    items.append(MapLocationItem(id: "hosp-builtin-\(idx)", type: .hospital, coordinate: coord, title: name, subtitle: address))
                }
            }
            if items.isEmpty {
                errorMessage = "Could not load hospitals. Try again later."
            } else {
                errorMessage = "Using cached hospital list. Some locations may be missing."
            }
        }

        hospitalLocations = ensureMtSinaiMorningside(in: items)
        applyFilter(search: searchText, aeds: aedLocations, hospitals: hospitalLocations, pharmacies: pharmacyLocations, showAeds: showAeds, showHospitals: showHospitals, showPharmacies: showPharmacies)
    }

    private func ensureMtSinaiMorningside(in items: [MapLocationItem]) -> [MapLocationItem] {
        let mtsCoord = Self.mtSinaiMorningside.coordinate
        let hasNearby = items.contains { item in
            abs(item.coordinate.latitude - mtsCoord.latitude) < 0.002 &&
            abs(item.coordinate.longitude - mtsCoord.longitude) < 0.002
        }
        if hasNearby { return items }
        return items + [Self.mtSinaiMorningside]
    }

    private func fetchHospitalsFromOpenDataSoft() async -> [MapLocationItem]? {
        let whereClause = "state=\"NY\" and (county=\"New York\" or county=\"Kings\" or county=\"Queens\" or county=\"Bronx\" or county=\"Richmond\")"
        var components = URLComponents(string: Self.openDataSoftHospitals)!
        components.queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "limit", value: "100")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return nil }

            var items: [MapLocationItem] = []
            for (idx, record) in results.enumerated() {
                guard let geoPoint = record["geo_point"] as? [String: Any],
                      let lat = geoPoint["lat"] as? Double ?? (geoPoint["lat"] as? Int).map(Double.init),
                      let lon = geoPoint["lon"] as? Double ?? (geoPoint["lon"] as? Int).map(Double.init),
                      (record["state"] as? String) == "NY" else { continue }

                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let name = (record["name"] as? String) ?? "Hospital"
                let address = (record["address"] as? String).map { a in
                    let city = record["city"] as? String ?? ""
                    let state = record["state"] as? String ?? ""
                    return [a, city, state].filter { !$0.isEmpty }.joined(separator: ", ")
                }
                items.append(MapLocationItem(id: "hosp-ods-\(idx)-\(lat)-\(lon)", type: .hospital, coordinate: coord, title: name, subtitle: address))
            }
            return items
        } catch {
            return nil
        }
    }

    private func fetchHospitalsFromOverpass() async -> [MapLocationItem]? {
        let bbox = "40.48,-74.26,40.92,-73.70"
        let query = "[out:json][timeout:25];(node[\"amenity\"=\"hospital\"](\(bbox));way[\"amenity\"=\"hospital\"](\(bbox)););out center tags;"
        guard let url = URL(string: Self.overpassAPI) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        request.httpBody = ("data=" + encoded).data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let elements = json["elements"] as? [[String: Any]] else { return nil }

            var items: [MapLocationItem] = []
            var seen = Set<String>()
            for (idx, el) in elements.enumerated() {
                var lat: Double?, lon: Double?
                if let la = el["lat"] as? Double, let lo = el["lon"] as? Double {
                    lat = la; lon = lo
                } else if let c = el["center"] as? [String: Any],
                          let la = c["lat"] as? Double ?? (c["lat"] as? Int).map(Double.init),
                          let lo = c["lon"] as? Double ?? (c["lon"] as? Int).map(Double.init) {
                    lat = la; lon = lo
                }
                guard let latitude = lat, let longitude = lon,
                      (-90...90).contains(latitude), (-180...180).contains(longitude) else { continue }

                let tags = el["tags"] as? [String: Any] ?? [:]
                let name = (tags["name"] as? String) ?? (tags["operator"] as? String) ?? "Hospital"
                let addr = [tags["addr:street"], tags["addr:housenumber"], tags["addr:city"]].compactMap { $0 as? String }.joined(separator: " ")
                let address = addr.isEmpty ? nil : addr
                let key = "\(latitude),\(longitude)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                items.append(MapLocationItem(id: "hosp-osm-\(idx)-\(latitude)-\(longitude)", type: .hospital, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: name, subtitle: address))
            }
            return items
        } catch {
            return nil
        }
    }

    private func fetchPharmacies() async {
        guard let items = await fetchPharmaciesFromOverpass(), !items.isEmpty else { return }
        pharmacyLocations = items
        applyFilter(search: searchText, aeds: aedLocations, hospitals: hospitalLocations, pharmacies: items, showAeds: showAeds, showHospitals: showHospitals, showPharmacies: showPharmacies)
    }

    private func fetchPharmaciesFromOverpass() async -> [MapLocationItem]? {
        let bbox = "40.50,-74.26,40.92,-73.70"
        let query = "[out:json][timeout:15];(node[\"amenity\"=\"pharmacy\"](\(bbox));way[\"amenity\"=\"pharmacy\"](\(bbox)););out center tags 250;"
        guard let url = URL(string: Self.overpassAPI) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        request.httpBody = ("data=" + encoded).data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let elements = json["elements"] as? [[String: Any]] else { return nil }

            var items: [MapLocationItem] = []
            var seen = Set<String>()
            for (idx, el) in elements.enumerated() {
                var lat: Double?, lon: Double?
                if let la = el["lat"] as? Double, let lo = el["lon"] as? Double {
                    lat = la; lon = lo
                } else if let c = el["center"] as? [String: Any],
                          let la = c["lat"] as? Double ?? (c["lat"] as? Int).map(Double.init),
                          let lo = c["lon"] as? Double ?? (c["lon"] as? Int).map(Double.init) {
                    lat = la; lon = lo
                }
                guard let latitude = lat, let longitude = lon,
                      (-90...90).contains(latitude), (-180...180).contains(longitude) else { continue }

                let tags = el["tags"] as? [String: Any] ?? [:]
                let name = (tags["name"] as? String) ?? (tags["brand"] as? String) ?? (tags["operator"] as? String) ?? "Pharmacy"
                let addr = [tags["addr:housenumber"], tags["addr:street"], tags["addr:city"]].compactMap { $0 as? String }.joined(separator: " ")
                let address = addr.isEmpty ? nil : addr
                let key = "\(latitude),\(longitude)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                items.append(MapLocationItem(id: "pharm-osm-\(idx)-\(latitude)-\(longitude)", type: .pharmacy, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: name, subtitle: address))
            }
            return items
        } catch {
            return nil
        }
    }

    private func applyFilter(search: String, aeds: [MapLocationItem], hospitals: [MapLocationItem], pharmacies: [MapLocationItem], showAeds: Bool, showHospitals: Bool, showPharmacies: Bool) {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            filteredAeds = showAeds ? aeds : []
            filteredHospitals = showHospitals ? hospitals : []
            filteredPharmacies = showPharmacies ? pharmacies : []
        } else {
            filteredAeds = showAeds ? aeds.filter { $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false) } : []
            filteredHospitals = showHospitals ? hospitals.filter { $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false) } : []
            filteredPharmacies = showPharmacies ? pharmacies.filter { $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false) } : []
        }
    }
}

extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            userLocation = loc.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Location error: \(error.localizedDescription)"
        }
    }
}
