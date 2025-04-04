import SwiftUI
import MapKit
import CoreLocation
import UserNotifications

// MARK: - App Models

struct Commitment {
    let id = UUID()
    var destination: CLLocationCoordinate2D
    var destinationName: String
    var deadline: Date
    var notificationSent: Bool = false
    var destinationAddress: String
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
}

class TrafficMonitor: ObservableObject {
    @Published var commitments: [Commitment] = []
    @Published var currentETAs: [UUID: TimeInterval] = [:]
    var locationManager: LocationManager
    private var trafficTimer: Timer?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        // Start monitoring traffic
        startMonitoring()
    }
    
    func startMonitoring() {
        // Cancel any existing timer to avoid duplication
        trafficTimer?.invalidate()
        
        // Start new monitoring schedule
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTrafficForCommitments()
        }
    }
    
    func stopMonitoring() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }
    
    deinit {
        stopMonitoring()
    }
    
    func addCommitment(destinationName: String, destinationAddress: String, deadline: Date) {
        // In a real app, you would geocode the address to get coordinates
        // This is simplified for the example
        let mockCoordinates = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        let newCommitment = Commitment(
            destination: mockCoordinates,
            destinationName: destinationName,
            deadline: deadline,
            destinationAddress: destinationAddress
        )
        
        commitments.append(newCommitment)
        checkTrafficForCommitment(commitment: newCommitment)
    }
    
    func checkTrafficForCommitments() {
        for commitment in commitments {
            checkTrafficForCommitment(commitment: commitment)
        }
    }
    
    func checkTrafficForCommitment(commitment: Commitment) {
        guard let currentLocation = locationManager.location else { return }
        
        calculateETA(from: currentLocation.coordinate, to: commitment.destination) { [weak self] eta in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentETAs[commitment.id] = eta
                
                // Check if we'll miss the deadline
                let arrivalTime = Date(timeIntervalSinceNow: eta)
                
                if let index = self.commitments.firstIndex(where: { $0.id == commitment.id }) {
                    if arrivalTime > commitment.deadline && !self.commitments[index].notificationSent {
                        // We're going to be late!
                        let formattedETA = self.formatTimeInterval(eta)
                        self.sendDelayNotification(
                            commitment: commitment,
                            currentLocation: currentLocation,
                            estimatedArrival: formattedETA
                        )
                        
                        // Mark notification as sent
                        self.commitments[index].notificationSent = true
                    }
                }
            }
        }
    }
    
    func calculateETA(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, completion: @escaping (TimeInterval) -> Void) {
        // In a real app, you would use the Maps API or similar for this
        // For this example, we'll simulate an ETA calculation
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculateETA { response, error in
            if let response = response {
                completion(response.expectedTravelTime)
            } else {
                // Fallback for sample or if API fails
                let distance = self.calculateDistance(from: origin, to: destination)
                let avgSpeed = 13.4 // meters per second (about 30mph)
                completion(distance / avgSpeed)
            }
        }
    }
    
    func calculateDistance(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return originLocation.distance(from: destinationLocation)
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: interval) ?? "Unknown"
    }
    
    func getAddressFromLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first {
                let address = [
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea
                ].compactMap { $0 }.joined(separator: ", ")
                completion(address.isEmpty ? "Unknown location" : address)
            } else {
                completion("Unknown location")
            }
        }
    }
    
    func sendDelayNotification(commitment: Commitment, currentLocation: CLLocation, estimatedArrival: String) {
        getAddressFromLocation(currentLocation) { currentAddress in
            // Create local notification
            let content = UNMutableNotificationContent()
            content.title = "You're going to be late!"
            content.body = "Based on current traffic, you won't make it to \(commitment.destinationName) by your deadline."
            
            // Create suggested message for sending
            let messageText = "I'm stuck in traffic at \(currentAddress ?? "current location"). My new ETA is \(estimatedArrival)."
            content.userInfo = ["messageText": messageText]
            
            // Ask if they want to send the message
            content.categoryIdentifier = "DELAY_NOTIFICATION"
            
            // Add actions
            let sendAction = UNNotificationAction(
                identifier: "SEND_MESSAGE",
                title: "Send Message",
                options: .foreground
            )
            
            let category = UNNotificationCategory(
                identifier: "DELAY_NOTIFICATION",
                actions: [sendAction],
                intentIdentifiers: []
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([category])
            
            // Schedule notification immediately
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func sendDelayMessage(for commitment: Commitment) {
        // In a real app, this would integrate with Messages or a social platform API
        // For this example, we just show how it would be triggered
        guard let index = commitments.firstIndex(where: { $0.id == commitment.id }),
              let currentLocation = locationManager.location,
              let eta = currentETAs[commitment.id] else {
            return
        }
        
        getAddressFromLocation(currentLocation) { currentAddress in
            let formattedETA = self.formatTimeInterval(eta)
            let messageText = "I'm stuck in traffic at \(currentAddress ?? "current location"). My new ETA is \(formattedETA)."
            
            // In a real app, you would send this message via the appropriate API
            print("Would send message: \(messageText)")
            
            // For Life360 integration, you would call their API here
            // This is just a placeholder for the actual implementation
            self.integrateWithLife360(message: messageText, location: currentLocation)
            
            // Mark notification as sent
            DispatchQueue.main.async {
                self.commitments[index].notificationSent = true
            }
        }
    }
    
    func integrateWithLife360(message: String, location: CLLocation) {
        // This is where you would implement Life360 API integration
        // For now, we'll just print to console
        print("Life360 integration: Sending message and location update")
        print("Message: \(message)")
        print("Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
}

// MARK: - App UI

struct CommitmentFormView: View {
    @ObservedObject var trafficMonitor: TrafficMonitor
    @State private var destinationName = ""
    @State private var destinationAddress = ""
    @State private var deadlineDate = Date()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Destination Details")) {
                    TextField("Destination Name", text: $destinationName)
                    TextField("Address", text: $destinationAddress)
                }
                
                Section(header: Text("Deadline")) {
                    DatePicker("Arrival Time", selection: $deadlineDate)
                }
                
                Button("Save Commitment") {
                    trafficMonitor.addCommitment(
                        destinationName: destinationName,
                        destinationAddress: destinationAddress,
                        deadline: deadlineDate
                    )
                    dismiss()
                }
                .disabled(destinationName.isEmpty || destinationAddress.isEmpty)
            }
            .navigationTitle("New Commitment")
        }
    }
}

struct CommitmentListView: View {
    @ObservedObject var trafficMonitor: TrafficMonitor
    @State private var showingAddForm = false
    
    var body: some View {
        List {
            ForEach(trafficMonitor.commitments, id: \.id) { commitment in
                VStack(alignment: .leading) {
                    Text(commitment.destinationName)
                        .font(.headline)
                    
                    Text(commitment.destinationAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Deadline: ")
                        Text(commitment.deadline, style: .time)
                        Text(commitment.deadline, style: .date)
                    }
                    .font(.caption)
                    
                    if let eta = trafficMonitor.currentETAs[commitment.id] {
                        let arrivalTime = Date(timeIntervalSinceNow: eta)
                        let isLate = arrivalTime > commitment.deadline
                        
                        HStack {
                            Text("ETA: ")
                            Text(trafficMonitor.formatTimeInterval(eta))
                            Text("(\(isLate ? "Late" : "On time"))")
                                .foregroundColor(isLate ? .red : .green)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("My Commitments")
        .toolbar {
            Button(action: {
                showingAddForm = true
            }) {
                Label("Add Commitment", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddForm) {
            CommitmentFormView(trafficMonitor: trafficMonitor)
        }
    }
}

struct MapView: View {
    @EnvironmentObject var trafficMonitor: TrafficMonitor
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
            .edgesIgnoringSafeArea(.all)
            .onReceive(trafficMonitor.locationManager.$location) { location in
                guard let location = location else { return }
                region.center = location.coordinate
            }
    }
}

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var autoMessageEnabled = false
    @State private var defaultMessage = "I'm stuck in traffic at [LOCATION]. My new ETA is [TIME]."
    @State private var showingMessageEditor = false
    
    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                Toggle("Automatic Message Sending", isOn: $autoMessageEnabled)
            }
            
            Section(header: Text("Default Message")) {
                Text(defaultMessage)
                    .foregroundColor(.secondary)
                Button("Edit Default Message") {
                    showingMessageEditor = true
                }
            }
            .sheet(isPresented: $showingMessageEditor) {
                MessageEditorView(message: $defaultMessage)
            }
            
            Section(header: Text("Connected Services")) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                    Text("Life360")
                    Spacer()
                    Text("Connected")
                        .foregroundColor(.green)
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct MessageEditorView: View {
    @Binding var message: String
    @Environment(\.dismiss) private var dismiss
    @State private var editingMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Default Message")) {
                    TextEditor(text: $editingMessage)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Available Placeholders")) {
                    Text("[LOCATION] - Your current location")
                    Text("[TIME] - Your estimated arrival time")
                }
            }
            .navigationTitle("Edit Message")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        message = editingMessage
                        dismiss()
                    }
                }
            }
            .onAppear {
                editingMessage = message
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var trafficMonitor: TrafficMonitor
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                CommitmentListView(trafficMonitor: trafficMonitor)
            }
            .tabItem {
                Label("Commitments", systemImage: "list.bullet.clipboard")
            }
            .tag(0)
            
            NavigationView {
                MapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(1)
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .onAppear {
            // Ensure proper setup when app launches
            setupNotificationHandling()
        }
    }
    
    func setupNotificationHandling() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
}

// MARK: - Notification Handling

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "SEND_MESSAGE" {
            // Handle the "Send Message" action
            if let messageText = response.notification.request.content.userInfo["messageText"] as? String {
                // In a real app, you would send this message
                print("Sending message: \(messageText)")
            }
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

// MARK: - App Entry Point

@main
struct TrafficDelayApp: App {
    let locationManager = LocationManager()
    let trafficMonitor: TrafficMonitor
    
    init() {
        // Initialize the traffic monitor with location manager
        let locationManager = LocationManager()
        self.locationManager = locationManager
        self.trafficMonitor = TrafficMonitor(locationManager: locationManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trafficMonitor)
        }
    }
}