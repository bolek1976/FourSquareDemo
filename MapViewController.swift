//
//  MapViewController.swift
//  FSDemo
//
//  Created by Boris Chirino on 24/02/16.
//  Copyright © 2016 Boris Chirino. All rights reserved.
//

import Foundation
import MapKit
import ObjectiveC


protocol MapViewLocationDelegate{
    func locationUpdated (userLocation: MKUserLocation)
}

class MapViewController : UIViewController, VenuesDataDelegate, MKMapViewDelegate{
    
    @IBOutlet weak var mapView: MKMapView!
     weak var parentVC :ContainerViewController? // avoid retain cycles from parent
     var anotations :Array<JPSThumbnailAnnotation>? = Array<JPSThumbnailAnnotation>()
     var mapViewLocationDelegate :MapViewLocationDelegate?
     var imageDownloadsInProgress :Array<IconDownloader> = []

    //MARK: View LifeCycle
    override func viewDidLoad() {
        self.mapView.showsUserLocation = true
        self.mapView.userTrackingMode = .Follow
        self.mapView.delegate = self
    }
    
    //MARK: Methods
    
    /**
    download the corresponding icon from the category array on the venue response. It take the prefix and suffix key to assemble the final url
    
    - parameter jpsItem:    JPSThumbnail Instance wich will be modified by setting the image property once the download task is complete
    - parameter annotation: JPSThumbnailAnnotation instance, used to update the view on the map.
    */
    func startDownloadIcon(jpsItem: JPSThumbnail, annotation :JPSThumbnailAnnotation){
        let itemIndex  = self.anotations?.indexOf(annotation)
        guard itemIndex != nil else {
            return
        }
        let downloader :IconDownloader = IconDownloader()
        downloader.jpsThumbnail = jpsItem
        downloader.completionHandler = { () -> Void in
            annotation.updateThumbnail(jpsItem, animated: true)
        }
        downloader.startDownload()
    }
    
    /**
      VenuesDataDelegate method wich is fullfilled once the webservice retrieve all data
     
     - parameter venues: Array of Venue's objects
     */
    
    func venueDataDownloaded(venues: Array<Venue>!) {
        venues.forEach { (item :Venue) -> () in
            let anotationItem :JPSThumbnail! = JPSThumbnail()
            anotationItem.title = item.name
            let category :NSDictionary = item.categories[0] as! NSDictionary
            let preffix = category["icon"]!["prefix"] as! String
            let suffix = category["icon"]!["suffix"] as! String
            anotationItem.iconUrl = String(format: "%@bg_64%@",preffix , suffix )
            anotationItem.subtitle = "\(item.stats.users.stringValue) users"
            anotationItem.coordinate = CLLocationCoordinate2DMake(item.location.lat.doubleValue, item.location.lng.doubleValue)
            anotationItem.disclosureBlock = { () -> Void in
                print("selected \(anotationItem.title)")
            }
            let anotation :JPSThumbnailAnnotation = JPSThumbnailAnnotation(thumbnail: anotationItem)
            
            self.anotations?.append(anotation)
            self.startDownloadIcon(anotationItem, annotation: anotation)
        }
        self.mapView.addAnnotations(self.anotations!)
    }
    
    override func didMoveToParentViewController(parent: UIViewController?) {
        parentVC = parent as? ContainerViewController
        self.mapViewLocationDelegate = parentVC
    }
    
    //MARK: MKMapViewDelegate
    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        if (view.conformsToProtocol(JPSThumbnailAnnotationViewProtocol)){
            view.performSelector("didDeselectAnnotationViewInMap:", withObject: mapView)
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        if (view.conformsToProtocol(JPSThumbnailAnnotationViewProtocol)){
            view.performSelector("didSelectAnnotationViewInMap:", withObject: mapView)
        }
    }
    
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation.conformsToProtocol(JPSThumbnailAnnotationProtocol)){
                return AnotationFactory.createAnotationView(mapViewAnotation: annotation as! JPSThumbnailAnnotation, mapInstance: mapView)
        }
        return nil
    }
    
    //MARK: MapViewLocationDelegate
    func mapView(mapView: MKMapView, didUpdateUserLocation userLocation: MKUserLocation) {
        self.mapViewLocationDelegate?.locationUpdated(userLocation)
    }
    
}


// This extension is used to inject a property to a JPSThumbnail instance. Due to the architecture of the component (JPSThumbnailAnnotationView)
// adding a property  in the interface of JPSThumbnail cause wird behaviours on the added property when creating the anotation with 
// JPSThumbnailAnnotation class

private var associationKey: UInt8 = 0

extension JPSThumbnail{

    var iconUrl: String! {
        get {
            return objc_getAssociatedObject(self, &associationKey) as? String
        }
        set (newValue) {
            if let newValue = newValue {
                objc_setAssociatedObject(
                    self,
                    &associationKey,
                    newValue as NSString?,
                   objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}


// This class is to supress the use of
//  [((NSObject<JPSThumbnailAnnotationProtocol> *)annotation) annotationViewInMap:mapView];
// with swift this kind of things cant be done like this, its a kind of upcasting but with pointer, so creating a factory with
// JPSThumbnailAnnotation object as parameter is the best approach here

class AnotationFactory: JPSThumbnailAnnotationView {
    class func createAnotationView(mapViewAnotation mapViewAnotation: JPSThumbnailAnnotation, mapInstance: MKMapView) -> MKAnnotationView{
      return mapViewAnotation.annotationViewInMap(mapInstance)
    }
}