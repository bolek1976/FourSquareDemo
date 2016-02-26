//
//  MainViewController.swift
//  FSDemo
//
//  Created by Boris Chirino on 24/02/16.
//  Copyright © 2016 Boris Chirino. All rights reserved.
//

import Foundation
import MapKit

/**
 *  take Array of venues to implementing class
 */
protocol VenuesDataDelegate {
    func venueDataDownloaded(venues :Array<Venue>!)
}

//MARK: ContainerViewController Class

class ContainerViewController :UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, MKMapViewDelegate, MapViewLocationDelegate {

    //MARK: class properties
    
    let kVenueCellIdentifier :String = "venueCell"
    let distanceFormatter = MKDistanceFormatter()
    let hud :SVProgressHUD = SVProgressHUD()
    var venuesDataDelegate :VenuesDataDelegate?
    var anotations :Array<JPSThumbnailAnnotation>? = Array<JPSThumbnailAnnotation>()

    
    lazy var mapViewController :MapViewController = {
        var mapVC : MapViewController = self.childViewControllers[0] as! MapViewController
        return mapVC
    }()
    
    lazy var locationManager :CLLocationManager = {
        let lm = CLLocationManager()
        lm.delegate = self
        return lm
    }()
    var Venues :Array<Venue>? = []
    

    @IBOutlet weak var tableView :UITableView!
    
//MARK: View lifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.venuesDataDelegate = self.mapViewController
        distanceFormatter.unitStyle = .Abbreviated
        distanceFormatter.units = .Metric
        let authStatus :CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        if (authStatus == CLAuthorizationStatus.NotDetermined){
            locationManager.requestWhenInUseAuthorization()
        }
        self.configureRestKit()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if (CLLocationManager.authorizationStatus() != .AuthorizedWhenInUse){
            self.title = "GPS not autorized!"
        }else{
            self.title = "Nearest restaurants"
            SVProgressHUD.showWithStatus("Warming up gps")
        }
        
    }
    

//MARK: TableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.Venues?.count)!
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:FourSquareCell = tableView.dequeueReusableCellWithIdentifier(kVenueCellIdentifier) as! FourSquareCell
        let venue :Venue = self.Venues![indexPath.row]
        cell.venueName.text = venue.name
        let distance :CLLocationDistance = venue.location.distance.doubleValue
        cell.venueDistance.text = distanceFormatter.stringFromDistance(distance)
        cell.venueCheckins.text = venue.stats.checkins.stringValue
        cell.venueTotalTips.text = venue.stats.tips != nil ? venue.stats.tips.stringValue : "-"
        return cell
    }
    
    
// MARK: My methods
    
    func switchView(sender: UIBarButtonItem) {
        sender.title = sender.title == "Map" ? "List" : "Map"
        if (sender.title == "List") { // Hide table view. Show map
            UIView.animateWithDuration(0.45, animations: { () -> Void in
                self.mapViewController.view.alpha = 1.0
                self.tableView.alpha = 0
                }, completion: { (Bool) -> Void in
                    self.tableView.alpha = 0
            })
            
        }else { // Hide map , Show TableView
            UIView.animateWithDuration(0.45, animations: { () -> Void in
                self.mapViewController.view.alpha = 0.0
                self.tableView.alpha = 1.0
                }, completion: { (Bool) -> Void in
                    self.tableView.alpha = 1.0
            })
        }
    }

    
    func configureRestKit() {
        // initialize AFNetworking HTTPClient
        let baseURL :NSURL = NSURL(string: "https://api.foursquare.com")!
        let httpClient :AFHTTPClient = AFHTTPClient(baseURL: baseURL)
        
        // initialize RestKit
        let objectManager :RKObjectManager = RKObjectManager(HTTPClient: httpClient)
        
        
        // object mappings
        let venueMapping :RKObjectMapping = RKObjectMapping(forClass: Venue.self)
        venueMapping.addAttributeMappingsFromDictionary(["name":"name","id":"venueID","categories":"categories"])
        
        let locationMapping :RKObjectMapping = RKObjectMapping(forClass: Location.self)
        locationMapping.addAttributeMappingsFromArray(["address", "city", "country", "crossStreet", "postalCode", "state", "distance", "lat", "lng"])
        
        let statsMapping :RKObjectMapping = RKObjectMapping(withClass: Stats.self)
        statsMapping.addAttributeMappingsFromDictionary(["checkinsCount": "checkins", "tipsCount": "tips", "usersCount": "users"])
        
        
        // parser relationships
        let locationRelationship = RKRelationshipMapping(fromKeyPath: "location", toKeyPath: "location", withMapping: locationMapping)
        venueMapping.addPropertyMapping(locationRelationship)
        
        let statsRelationship = RKRelationshipMapping(fromKeyPath: "stats", toKeyPath: "stats",withMapping: statsMapping)
        venueMapping.addPropertyMapping(statsRelationship)
        
        //response descriptor
        let responseDescriptor = RKResponseDescriptor(mapping: venueMapping, method: RKRequestMethod.GET, pathPattern: "/v2/venues/search", keyPath: "response.venues", statusCodes: NSIndexSet(index: 200))
        
        objectManager.addResponseDescriptor(responseDescriptor)
    }
    
    

    func loadVenues(coordinates :CLLocation!)
    {
        let latLon: String = "\(coordinates.coordinate.latitude,coordinates.coordinate.longitude)".stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "()"))
        let clientID: String = "TZM5LRSRF1QKX1M2PK13SLZXRXITT2GNMB1NN34ZE3PVTJKT"
        let clientSecret: String = "250PUUO4N5P0ARWUJTN2KHSW5L31ZGFDITAUNFWVB5Q4WJWY"
        let queryParams: [String : AnyObject] = ["ll" :latLon, "client_id" :clientID, "client_secret" :clientSecret, "categoryId" :"4bf58dd8d48988d1c4941735", "v" :"20130815", "limit" : NSNumber(int: 10)]
        
        RKObjectManager.sharedManager().getObjectsAtPath("/v2/venues/search", parameters: queryParams, success: { (requestOperation, mappingResult) -> Void in
            
            self.Venues = (mappingResult as RKMappingResult).array() as? Array<Venue>
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                SVProgressHUD.dismiss()
                self.venuesDataDelegate?.venueDataDownloaded(self.Venues)
                self.tableView.reloadData()
            })
            }) { (operation, error) -> Void in
                SVProgressHUD.setStatus(error.localizedDescription)
                SVProgressHUD.dismissWithDelay(2)
        }
    }
    
// MARK: LocationManager Delegate
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if (status == .AuthorizedWhenInUse){
            self.title = "Nearest restaurants"
        }else{
            SVProgressHUD.setStatus("Cant get gps data. Restart and Authorize")
            SVProgressHUD.dismissWithDelay(3);
        }
    }
    
//MARK: MapViewLocationDelegate
    func locationUpdated(userLocation: MKUserLocation) {
        SVProgressHUD.setStatus("Loading venues")
        loadVenues(userLocation.location)
        print("got it \(userLocation.location)")
    }
    
    
    
}// CLASS


//MARK: FourSquareCell Class
class FourSquareCell: UITableViewCell {
    
    @IBOutlet weak var venueName: UILabel!
    @IBOutlet weak var venueDistance: UILabel!
    @IBOutlet weak var venueCheckins: UILabel!
    @IBOutlet weak var venueTotalTips: UILabel!
    

}
