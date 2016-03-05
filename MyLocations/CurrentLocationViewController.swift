//
//  FirstViewController.swift
//  MyLocations
//
//  Created by 1024 on 04.03.16.
//  Copyright © 2016 Sasha Lexor. All rights reserved.
//

import UIKit
import CoreLocation

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate {  //  для работы с CoreLocation нужно соответствовать протоколу CLLocationManagerDelegate
    
    @IBOutlet weak var messageLable : UILabel!
    @IBOutlet weak var latitudeLable : UILabel!
    @IBOutlet weak var longitudeLable : UILabel!
    @IBOutlet weak var adressLable : UILabel!
    @IBOutlet weak var tagButton : UIButton!
    @IBOutlet weak var getButton : UIButton!
    
    let locationManager = CLLocationManager()                                      // объект предоставляющий GPS координаты
    var location : CLLocation?                                                      // храним текущее положение пользователя
    var updatingLocation = false
    var lastLocationError : NSError?
    let geocoder = CLGeocoder()                                                     // преобразует координаты в адресс (используя сервер apple)
    var placemark : CLPlacemark?                                                     // содержит адресс после преоброзавания координат
    var performingReverceGeocoding = false
    var lastGeocodingError : NSError?
    var timer : NSTimer?
    
    
    @IBAction func getLocation() {
        let authStatus = CLLocationManager.authorizationStatus()                   //  проверяем статус разрешения использования местоположения пользователем
        
        if authStatus == CLAuthorizationStatus.NotDetermined {                      //  если статус "не разрешен"б то запрашиваем разрешение
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == CLAuthorizationStatus.Denied || authStatus == CLAuthorizationStatus.Restricted {
            showLocationServicesDenidedAcsess()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            
            //
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            
            startLocationManager()
            updateLabels()
            configureGetButton()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateLabels()
        configureGetButton()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // показываем аллерт когда пользователь не разрешил использовать местоположение
    
    func showLocationServicesDenidedAcsess() {
        let allert = UIAlertController(title: "Location Services Disabled", message: "Please enable location services for this app in Settings.", preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
        allert.addAction(okAction)
        presentViewController(allert, animated: true, completion: nil)
        
    }
    
    
    // устанавливаем нужный заголовок для кнопки
    
    func configureGetButton() {
        if updatingLocation {
            getButton.setTitle("Stop", forState: .Normal)
        } else {
            getButton.setTitle("Get My Location", forState: .Normal)
        }
    }

    
// -------------------- CLLocationManagerDelegate ------------------------- //
    // MARK: - CLLocationManagerDelegate


    // вызывается если locationManager не смог получить местоположение
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Did fail with error : \(error)")
        
        if error.code == CLError.LocationUnknown.rawValue {
            return
        }
        
        lastLocationError = error
        stopLocationManager()
        updateLabels()
        configureGetButton()
    }
    
    func stopLocationManager() {
        print("Stop location manager")
        if updatingLocation {
            
            if let timer = timer {
                timer.invalidate()
            }
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
        }
    }
    
    func startLocationManager() {
        print("Start location manager")
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self                                            // присваивает делегат для объекта
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters      // задаем точность вычисления координат
            locationManager.startUpdatingLocation()                                    // начинаем обновление позиции
            updatingLocation = true
            
            timer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: Selector("didTimeOut"), userInfo: nil, repeats: false)
        }
    }
    
    func didTimeOut() {
        print("*** Time out")
        if location == nil {
            stopLocationManager()
            lastLocationError = NSError(domain: "MyLocationsErrorDomain", code: 1, userInfo: nil)
            updateLabels()
            configureGetButton()
        }
    }
    
    
    // сообщает делегату о новом местоположении
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        print("Did update new location : \(newLocation)")
        
        if newLocation.timestamp.timeIntervalSinceNow < -5 {        // если объект был создан (получен) более 5 секунд назад
            return
        }
        
        if newLocation.horizontalAccuracy < 0 {                     // если радиуз имеет отридцательное значение, то измерения не верны
            return
        }
        
        var distance = CLLocationDistance(DBL_MAX)  // задает начальное значение = макс. Float
        if let location = location {
            distance = newLocation.distanceFromLocation(location)       // вычисляем дистанцию между хранящимся и новым местоположением
        }
     
        
        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {   // если новое измерение более точное (имеет меньший радиус)
            lastLocationError = nil
            location = newLocation
            updateLabels()
            
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {          // если полученное местоположение достаточно точное 
                                                                                            // (радиус меньше или равен радиусу locationManager)
                print("*** We're done!")
                stopLocationManager()
                configureGetButton()
                
                if distance > 0 {                                                 // ?? если дистанция м-ду местоположениями еще велика, то останавливаем процесс получения адреса
                                                                                    // или если дистанция 0, то нам не нужно получать новый арес
                    performingReverceGeocoding = false
                }
            }
            
            if !performingReverceGeocoding {
                print("*** Going to geocode")
                performingReverceGeocoding = true
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: {
                    placemarks, error in
                    print("*** Found placemarks: \(placemarks), error: \(error)")
                    self.lastLocationError = error
                    if error == nil, let p = placemarks where !p.isEmpty {
                        self.placemark = p.last!
                    } else {
                        self.placemark = nil
                    }
                    self.performingReverceGeocoding = false
                    self.updateLabels()
                })
            } else if distance < 1.0 {                                                                      // если дистанция между местоположениями отличается на 1м и 
                let timeInterval = newLocation.timestamp.timeIntervalSinceDate(location!.timestamp)         // а разница в получении координат составляет больше 10 секунд
                if timeInterval > 10 {
                    print("*** Force done!")
                    stopLocationManager()
                    updateLabels()
                    configureGetButton()
                }
            }
        }
        
        
    }
    
    
    // ф-я обновляет пользовательский интерфейс и выводит необходимые значения
    
    func updateLabels() {
        if let location = location {
            latitudeLable.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLable.text = String(format: "%.8f", location.coordinate.longitude)
            tagButton.hidden = false
            messageLable.text = ""
            
            if let placemark = placemark {
                adressLable.text = stringFromPlacamark(placemark)
            } else if performingReverceGeocoding {
                adressLable.text = "Searching for Address..."
            } else if lastLocationError != nil {
                adressLable.text = "Error Finding Address"
            } else {
                adressLable.text = "No Adress Found"
            }
            
        } else {
            latitudeLable.text = ""
            longitudeLable.text = ""
            adressLable.text = ""
            tagButton.hidden = true
            messageLable.text = "Tap 'Get My Location' to Start"
        }
        
        let statusMessage : String
        if let error = lastLocationError {
                if error.domain == kCLErrorDomain && error.code == CLError.Denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
        } else if !CLLocationManager.locationServicesEnabled() {
            statusMessage = "Location Services Disabled"
        } else if updatingLocation {
            statusMessage = "Searching..."
        } else {
            statusMessage = "Tap 'Get My Location' to Start"
        }
        
        messageLable.text = statusMessage
        
    }
    
    
    func stringFromPlacamark(placemark: CLPlacemark) -> String {
        var line1 = ""
        if let s = placemark.subThoroughfare {
            line1 += s + " "
        }
        if let s = placemark.thoroughfare {
            line1 += s
        }
        
        var line2 = ""
        if let s = placemark.locality {
            line2 += s + " "
        }
        if let s = placemark.administrativeArea {
            line2 += s + " "
        }
        if let s = placemark.postalCode {
            line2 += s
        }
            
        return line1 + "\n" + line2
    }
    
    
    

}

