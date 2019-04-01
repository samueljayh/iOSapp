//
//  MapView.swift
//  walkMedfordiOS
//
//  Created by Sam Hollingsworth on 11/26/18.
//  Copyright © 2018 walkMedford. All rights reserved.
//
import UIKit
import MapKit

class MapView: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    // Variables for color of elements
    var red = UIColor(red: 200, green: 0, blue: 0, alpha: 1)
    var green = UIColor(red: 0, green: 200, blue: 0, alpha: 1)
    var blue = UIColor(red: 0, green: 0, blue: 200, alpha: 1)
    
    // Variables for HTTP Requests
    let defaultSession = URLSession(configuration: .default)
    var dataTask: URLSessionDataTask?
    
    // Variables for Map, User Location, and Route
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var desiredRoute: Route?                            // User's chosen route
    var routePolyline : MKPolyline?                     // Line for route that visits landmarks
    var directionsToRoutePolyline : MKPolyline?         // Line for user to follow to get to the start of the route
    
    // Variable for selected landmark by user
    var selectedLandmark: Landmark!
    
    // Variable for directions
    @IBOutlet weak var directionsInMapsButton: UIButton!
    
    /*
     Purpose: To call functions when view is loaded
     Notes:
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        wakeUpServer()
        
        // Set up Map
        locationManager.delegate = self
        mapView.delegate = self
        mapView.showsUserLocation = true
        directionsInMapsButton.isHidden = true
        centerOnUser()
        setUpUserTrackingButton()
    }
    
    /*
     Purpose: To set up the route on the map
     Notes:
     */
    func setUpRoute() {
        
        initPolyline()
        
        if (desiredRoute != nil) {
            addRoute()
        } else {
            print("DESIRED ROUTE NIL")
        }
    }
    
    /*
     Purpose: To set up user tracking button
     Notes:
     */
    func setUpUserTrackingButton() {
        
        let button = MKUserTrackingButton(mapView: mapView)
        button.layer.backgroundColor = UIColor(white: 1, alpha: 0.9).cgColor
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 5
        
        view.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -60).isActive = true
        button.leadingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -50).isActive = true
    }
    
    /*
     Purpose: To center the map on the user
     Notes:
     */
    func centerOnUser() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /*
     Purpose: To update the user's location while moving around the map
     Notes:
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.first!
        let coordinateRegion = MKCoordinateRegion.init(center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(coordinateRegion, animated: true)
        
        locationManager.stopUpdatingLocation()
    }
    
    /*
     Purpose: To clear the map of overlays or annotations
     Notes:
     */
    func clearMap() {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
    }
 
    /*
     Purpose: To set up polyline
     Notes:
     */
    func initPolyline() {
        var polyInit = [CLLocationCoordinate2D]()
        
        if (desiredRoute == nil) {
            polyInit = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        } else {
            print(desiredRoute!.name)
            for landmark in desiredRoute!.landmarks {
                polyInit.append(landmark.location)
            }
        }
        
        routePolyline = MKPolyline(coordinates: &polyInit, count: polyInit.count)
        directionsToRoutePolyline = MKPolyline(coordinates: &polyInit, count: polyInit.count)
    }
    
    /*
     Purpose: To add the desired route to the map
     Notes:
     */
    func addRoute() {
        if (desiredRoute!.landmarks.count == 0) {
            return
        }
        
        // Create a walkable route, loop through and set walking paths between consecutive landmarks
        for index in 0..<(desiredRoute!.landmarks.count-1) {
            
            let sourceLocation = desiredRoute!.landmarks[index].location
            let destinationLocation = desiredRoute!.landmarks[index + 1].location
            
            let sourcePlacemark = MKPlacemark(coordinate: sourceLocation, addressDictionary: nil)
            let destinationPlacemark = MKPlacemark(coordinate: destinationLocation, addressDictionary: nil)
            
            let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
            let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
            
            let directionRequest = MKDirections.Request()
            directionRequest.source = sourceMapItem
            directionRequest.destination = destinationMapItem
            directionRequest.transportType = .walking
            
            let directions = MKDirections(request: directionRequest)
            
            directions.calculate {
                (response, error) -> Void in
                
                guard let response = response else {
                    if let error = error {
                        print("Error: \(error)")
                    }
                    return
                }
                
                // Sets up polyline on Map
                let route = response.routes[0]
                self.routePolyline = route.polyline
                self.mapView.addOverlay((self.routePolyline!), level: MKOverlayLevel.aboveRoads)
                
                let rect = route.polyline.boundingMapRect
                self.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
            }
        }
        
        centerOnUser()
        
        // Add annotations, landmarks, and directions to start
        //addStartEndAnnotations()
        addRouteFromUserToStart()
        addLandmarkAnnotations()
    }
    
    /*
     Purpose: To add annotations to the start and end of the desired route
     Notes:
     */
    func addStartEndAnnotations() {
        let sourceLocation = desiredRoute!.landmarks[0].location
        let destinationLocation = desiredRoute!.landmarks[desiredRoute!.landmarks.count - 1].location
        
        let startAnnotation = StartEndAnnotation(title: "Start of Route", coordinate: sourceLocation)
        let endAnnotation = StartEndAnnotation(title: "End of Route", coordinate: destinationLocation)
        
        self.mapView.addAnnotation(startAnnotation)
        self.mapView.addAnnotation(endAnnotation)
    }
    
    /*
     Purpose: To add route from user's location to start of desired route
     Notes:
     */
    func addRouteFromUserToStart() {
        let sourceLocation = locationManager.location!.coordinate
        let destinationLocation = desiredRoute!.landmarks[0].location
        
        let sourcePlacemark = MKPlacemark(coordinate: sourceLocation, addressDictionary: nil)
        let destinationPlacemark = MKPlacemark(coordinate: destinationLocation, addressDictionary: nil)
        
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        let directionRequest = MKDirections.Request()
        directionRequest.source = sourceMapItem
        directionRequest.destination = destinationMapItem
        directionRequest.transportType = .walking
        
        let directions = MKDirections(request: directionRequest)
        
        directions.calculate {
            (response, error) -> Void in
            
            guard let response = response else {
                if let error = error {
                    print("Error: \(error)")
                }
                
                return
            }
            
            // Sets up polyline on Map
            let route = response.routes[0]
            self.directionsToRoutePolyline = route.polyline
            self.mapView.addOverlay((self.directionsToRoutePolyline!), level: MKOverlayLevel.aboveRoads)
            
            let rect = route.polyline.boundingMapRect
            self.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
            self.directionsInMapsButton.isHidden = false
        }
        
        centerOnUser()
    }
    
    /*
     Purpose: To add landmarks along the route
     Notes: Bad way to add landmarks, need to add custom classes for separate annotations for landmarks and start and end of route
     */
    func addLandmarkAnnotations() {
        
        for landmark in desiredRoute!.landmarks {
            let landmarkAnnotation = LandmarkAnnotation(title: landmark.title,
                                                        subtitle: landmark.address,
                                                        coordinate: landmark.location)
            self.mapView.addAnnotation(landmarkAnnotation)
        }
        
        centerOnUser()
    }
    
    /*
     Purpose: To format the route lines
     Notes:
     */
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 6.0
        
        if overlay is MKPolyline {
            if overlay as? MKPolyline == routePolyline {
                renderer.strokeColor = red
            } else if overlay as? MKPolyline == directionsToRoutePolyline {
                renderer.strokeColor = blue
            }
        }
        
        return renderer
    }
    
    /*
     Purpose: To format the landmark annotations
     Notes:
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "marker"
        var view: MKMarkerAnnotationView
        
        if let annotation = annotation as? LandmarkAnnotation {
            
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                as? MKMarkerAnnotationView {
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            
            view.canShowCallout = true
            view.glyphImage = UIImage(named: annotation.imageName ?? "landmark")
            view.markerTintColor = red
            view.subtitleVisibility = MKFeatureVisibility.visible
            
        } else if let annotation = annotation as? StartEndAnnotation {
            
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.markerTintColor = green
            
        } else {
            return nil
        }
        
        return view
    }
    
    /*
     Purpose: To show more information when landmark is selected
     Notes:
     */
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        for landmark in desiredRoute!.landmarks {
            if (landmark.title == view.annotation?.title) {
                selectedLandmark = landmark
            }
        }
        
        performSegue(withIdentifier: "segueMapToLandmark", sender: self)
    }
    
    /*
     Purpose: To pass data to next view
     Notes:
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "segueMapToLandmark") {
            if let destinationVC = segue.destination as? LandmarkView {
                destinationVC.landmark = selectedLandmark
            }
        }
    }
    
    /*
     Purpose: To open Apple Maps with directions to route
     Notes:
     */
    @IBAction func directionsInMapsButton(_ sender: Any) {
        
        let placemark = MKPlacemark(coordinate: desiredRoute!.landmarks[0].location, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Start of Route"
        
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    /*
     Purpose: To wake up the Heroku server so it is prepared for requests in RouteSelectionView
     Notes:
     */
    func wakeUpServer() {
        dataTask?.cancel()
        
        if var urlComponents = URLComponents(string: "https://walkmedford.herokuapp.com/") {
            urlComponents.query = ""
            
            guard let url = urlComponents.url else { return }
            dataTask = defaultSession.dataTask(with: url) { data, response, error in
                defer { self.dataTask = nil }
                
                if let error = error {
                    print("DataTask error: " + error.localizedDescription + "\n")
                } else if let _ = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    
                    print("Server is woken up")
                }
            }
        }
        
        dataTask?.resume()
    }
}
