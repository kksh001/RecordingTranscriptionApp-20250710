import Foundation
import CoreLocation
import Network

// MARK: - Network Region Manager
@MainActor
class NetworkRegionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentRegion: NetworkRegion = .unknown
    @Published var recommendedService: TranslationServiceType = .qianwen
    @Published var isDetectionComplete: Bool = false
    @Published var networkStatus: NWPath.Status = .requiresConnection
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var debugMessages: [String] = []
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationAuthorizationStatus = locationManager.authorizationStatus
        setupLocationManager()
        setupNetworkMonitor()
        detectRegion()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
    }
    
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkStatus = path.status
                self?.detectRegionBasedOnNetwork(path: path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Region Detection
    
    func detectRegion() {
        // First try location-based detection
        detectRegionByLocation()
        
        // Fallback to network-based detection
        detectRegionByNetwork()
    }
    
    private func detectRegionByLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorized, .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // Fallback to network detection
            detectRegionByNetwork()
        @unknown default:
            detectRegionByNetwork()
        }
    }
    
    private func detectRegionByNetwork() {
        Task {
            let detectedRegion = await performNetworkBasedDetection()
            await MainActor.run {
                updateRegion(detectedRegion)
            }
        }
    }
    
    private func detectRegionBasedOnNetwork(path: NWPath) {
        if path.status == .satisfied {
            detectRegionByNetwork()
        }
    }
    
    private func performNetworkBasedDetection() async -> NetworkRegion {
        await addDebugMessageAsync("🔍 Starting network-based region detection...")
        // Try to detect region by checking connectivity to specific services
        let isChinaMainland = await checkChinaMainlandConnectivity()
        let result = isChinaMainland ? NetworkRegion.mainlandChina : NetworkRegion.overseas
        await addDebugMessageAsync("🌐 Network detection result: \(result.displayName)")
        return result
    }
    
    private func checkChinaMainlandConnectivity() async -> Bool {
        await addDebugMessageAsync("🔗 Checking China mainland connectivity...")
        // Check if we can reach China-specific services
        let chinaDomains = [
            "baidu.com",
            "qq.com",
            "weibo.com"
        ]
        
        var successCount = 0
        for domain in chinaDomains {
            await addDebugMessageAsync("🌐 Testing domain: \(domain)")
            if await canReachDomain(domain) {
                await addDebugMessageAsync("✅ Successfully reached: \(domain)")
                successCount += 1
            } else {
                await addDebugMessageAsync("❌ Failed to reach: \(domain)")
            }
        }
        
        let isChinaMainland = successCount > 0
        await addDebugMessageAsync("📊 China connectivity test: \(successCount)/\(chinaDomains.count) domains reachable")
        await addDebugMessageAsync("🌍 Result: \(isChinaMainland ? "China Mainland" : "Overseas")")
        return isChinaMainland
    }
    
    private func canReachDomain(_ domain: String) async -> Bool {
        guard let url = URL(string: "https://\(domain)") else { 
            await addDebugMessageAsync("❌ Invalid URL for domain: \(domain)")
            return false 
        }
        
        do {
            await addDebugMessageAsync("⏳ Connecting to \(domain)...")
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode < 400
                await addDebugMessageAsync("📡 \(domain) response: \(httpResponse.statusCode) \(success ? "✅" : "❌")")
                return success
            }
        } catch {
            await addDebugMessageAsync("🚫 Network error for \(domain): \(error.localizedDescription)")
        }
        
        return false
    }
    
    private func updateRegion(_ region: NetworkRegion) {
        addDebugMessage("🔄 Updating region...")
        addDebugMessage("📍 Previous region: \(currentRegion.displayName)")
        addDebugMessage("📍 New region: \(region.displayName)")
        
        currentRegion = region
        recommendedService = region.recommendedService
        isDetectionComplete = true
        
        addDebugMessage("🌍 ✅ Region updated to: \(region.displayName)")
        addDebugMessage("🔧 ✅ Recommended service: \(recommendedService.displayName)")
        addDebugMessage("✅ Detection marked as complete")
    }
    
    // MARK: - Public Methods
    
    func getRecommendedService() -> TranslationServiceType {
        return recommendedService
    }
    
    func forceRefreshDetection() {
        addDebugMessage("🔄 Force refresh detection requested")
        addDebugMessage("📱 Current network status: \(networkStatus)")
        addDebugMessage("📍 Current location permission: \(locationAuthorizationStatus)")
        isDetectionComplete = false
        addDebugMessage("❌ Detection marked as incomplete, starting fresh detection...")
        detectRegion()
    }
    
    func requestLocationPermission() {
        // 明确请求位置权限
        addDebugMessage("🔒 Requesting location permission...")
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            addDebugMessage("⚠️ Location permission previously denied. Please enable in Settings.")
        case .authorized, .authorizedWhenInUse, .authorizedAlways:
            addDebugMessage("✅ Location permission already granted. Requesting current location...")
            locationManager.requestLocation()
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func setManualRegion(_ region: NetworkRegion) {
        updateRegion(region)
    }
    
    func clearDebugMessages() {
        debugMessages.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func addDebugMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.debugMessages.append(message)
            print(message) // Also print to console
        }
    }
    
    private func addDebugMessageAsync(_ message: String) async {
        await MainActor.run {
            debugMessages.append(message)
            print(message) // Also print to console
        }
    }
    
    // MARK: - Debug Methods
    
    func debugInfo() -> String {
        var info = "Network Region Manager Debug Info:\n"
        info += "- Current Region: \(currentRegion.displayName)\n"
        info += "- Recommended Service: \(recommendedService.displayName)\n"
        info += "- Detection Complete: \(isDetectionComplete)\n"
        info += "- Network Status: \(networkStatus)\n"
        return info
    }
}

// MARK: - CLLocationManagerDelegate
extension NetworkRegionManager: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first,
                  let country = placemark.country else {
                Task { @MainActor in
                    self?.detectRegionByNetwork()
                }
                return
            }
            
            let region: NetworkRegion = (country == "China" || country == "中国") ? .mainlandChina : .overseas
            Task { @MainActor in
                self.updateRegion(region)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location detection failed: \(error)")
        Task { @MainActor in
            detectRegionByNetwork()
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthorizationStatus = manager.authorizationStatus
        }
        
        switch manager.authorizationStatus {
        case .authorized, .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            Task { @MainActor in
                detectRegionByNetwork()
            }
        default:
            break
        }
    }
}