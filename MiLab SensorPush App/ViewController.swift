//
//  ViewController.swift
//  MiLab SensorPush App
//
//  Created by Eddie Carrizales on 6/13/23.
//

import UIKit
import CoreBluetooth
import Alamofire

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    //Service id of bluetooth device
    let SENSORPUSH_DEVICE_SERVICE = "EF090000-11D6-42BA-93B8-9DD7EC090AB0"
    let SENSORPUSH_NAME = "SensorPush HTP.xw 69D"
    
    //Characteristics of bluetooth device
    var TEMPERATURE_CHARACTERISTIC = "EF090080-11D6-42BA-93B8-9DD7EC090AA9"
    var HUMIDITY_CHARACTERISTIC = "EF090081-11D6-42BA-93B8-9DD7EC090AA9"
    var PRESSURE_CHARACTERISTIC = "EF090082-11D6-42BA-93B8-9DD7EC090AA9"
    
    var temperatureCharacteristic: CBCharacteristic!
    var humidityCharacteristic: CBCharacteristic!
    var pressureCharacteristic: CBCharacteristic!
    
    //Variables
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var sendToDatabaseTimer : Timer?
    var writeReadTimerTemperature : Timer?
    var writeReadTimerHumidity : Timer?
    var writeReadTimerPressure : Timer?
    var ResultsList: [String] = ["", "", ""]
    var timeDelay = 5.0 //dont make this less than 5.0 seconds
    
    //Connected outlets
    @IBOutlet weak var uiSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var shadowView: UIView!
    
    
    //Connected actions
    @IBAction func uiSwitchValueChanged(sender: UISwitch){
        if (sender.isOn) {
            print("Switch is ON")
            //Keep sending data to server
            startTimer()
            
        } else {
            print("Switch is OFF")
            stopTimer()
        }
    } //end of function
    
    func startTimer() {
        guard sendToDatabaseTimer == nil else { return }
        guard writeReadTimerTemperature == nil else { return }
        guard writeReadTimerHumidity == nil else { return }
        guard writeReadTimerPressure == nil else { return }
        
        sendToDatabaseTimer = Timer.scheduledTimer(timeInterval: timeDelay, target: self, selector: #selector(self.sendToDatabase), userInfo: nil, repeats: true)
        
        writeReadTimerTemperature = Timer.scheduledTimer(timeInterval: timeDelay - 0.5, target: self, selector: #selector(self.writeAndReadTemperature), userInfo: nil, repeats: true)
        
        writeReadTimerHumidity = Timer.scheduledTimer(timeInterval: timeDelay - 0.5, target: self, selector: #selector(self.writeAndReadHumidity), userInfo: nil, repeats: true)

        writeReadTimerPressure = Timer.scheduledTimer(timeInterval: timeDelay - 0.5, target: self, selector: #selector(self.writeAndReadPressure), userInfo: nil, repeats: true)
        
    }
    
    func stopTimer() {
        sendToDatabaseTimer?.invalidate()
        sendToDatabaseTimer = nil
        
        writeReadTimerTemperature?.invalidate()
        writeReadTimerTemperature = nil
        
        writeReadTimerHumidity?.invalidate()
        writeReadTimerHumidity = nil
        
        writeReadTimerPressure?.invalidate()
        writeReadTimerPressure = nil
    }
    
    @objc func writeAndReadTemperature() {
        writeBLEData(currentCharacteristic: temperatureCharacteristic, str: "01000000") //number sensorpush requires this number
        readBLEData(currentCharacteristic: temperatureCharacteristic)
    }
    @objc func writeAndReadHumidity() {
        writeBLEData(currentCharacteristic: humidityCharacteristic, str: "01000000") //number sensorpush requires this number
        readBLEData(currentCharacteristic: humidityCharacteristic)
    }
    @objc func writeAndReadPressure() {
        writeBLEData(currentCharacteristic: pressureCharacteristic, str: "01000000") //number sensorpush requires this number
        readBLEData(currentCharacteristic: pressureCharacteristic)
    }
    
    @objc func sendToDatabase() {
        
        //----send Data----
        print("------------------- SENT: -------------------")
        print(ResultsList)
        print("---------------------------------------------")
        
        let parameters = [
            "Temperature": ResultsList[0],
            "Humidity": ResultsList[1],
            "Pressure": ResultsList[2]
        ] as [String : String]
        
        AF.request("http://172.16.136.143:8080/Sensor_THP/SensorPush", method: .put, parameters: parameters, encoder: JSONParameterEncoder.default).response { response in debugPrint(response)}
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Attempt to make a BLE connection

        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.scanForBLEDevice), userInfo: nil, repeats: false)
        
        activityIndicator.startAnimating()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //close BLE connection if it exists
    }
    
    @objc func scanForBLEDevice() {
        print("Scanning for bluetooth device")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
        
        //Check if the device found has the name of the device that we want
        if device?.contains(SENSORPUSH_NAME) == true {
            print("Found Peripheral name =\(peripheral.name!)")
            centralManager.stopScan()
            connectedPeripheral = peripheral
            connectedPeripheral.delegate = self
            centralManager.connect(connectedPeripheral, options: nil)
        } //end of if
    } //ed of func
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("Connected to the device!")
        
        hideActivityIndicator()
        
        //Call to discover the services available in the device
        connectedPeripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        print("--------------------------------------------")
        print("Service count=\(peripheral.services!.count)")
        
        //Loop to discover all the services of the device
        for service in peripheral.services! {
            print("Service =\(service)")
            
            //Discover all characteristics in each service
            let aService = service as CBService
            if service.uuid == CBUUID(string: SENSORPUSH_DEVICE_SERVICE) {
                
                //call the did discover characteristics to discover them
                peripheral.discoverCharacteristics(nil, for: aService)
                
            } //end of if
        } //end of loop
        print("--------------------------------------------")
    } //end of func
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("\nCHARACTERISTICS IN " + SENSORPUSH_DEVICE_SERVICE + ":\n")
        
        //loop to discover all the characteristics in a service of the device
        for characteristic in service.characteristics! {
            print("Characteristic =\(characteristic)")
        } //end of loop
        
        print("--------------------------------------------")
        
        //loop to find and write to specific characteristics
        for characteristic in service.characteristics! {
            let aCharacteristic = characteristic as CBCharacteristic
            
            //Write to this characteristic, put more in the list to use more
            if aCharacteristic.uuid == CBUUID(string: TEMPERATURE_CHARACTERISTIC) {
                print("\n WRITING TO " + TEMPERATURE_CHARACTERISTIC + ":\n")
                temperatureCharacteristic = aCharacteristic
            }
            
            if aCharacteristic.uuid == CBUUID(string: HUMIDITY_CHARACTERISTIC) {
                print("\n WRITING TO " + HUMIDITY_CHARACTERISTIC + ":\n")
                humidityCharacteristic = aCharacteristic
            }
            
            if aCharacteristic.uuid == CBUUID(string: PRESSURE_CHARACTERISTIC) {
                print("\n WRITING TO " + PRESSURE_CHARACTERISTIC + ":\n")
                pressureCharacteristic = aCharacteristic
            }
            
        } //end of loop
        print("--------------------------------------------")
    } //end of func
    
    func writeBLEData(currentCharacteristic: CBCharacteristic, str: String) {

        //print("wrote")
        let data = str.dataFromHexadecimalString()
        //print(data!)

        connectedPeripheral.writeValue(data!, for: currentCharacteristic, type: CBCharacteristicWriteType.withResponse)
        
    }
    
    func readBLEData(currentCharacteristic: CBCharacteristic) {
        //print("read")
        connectedPeripheral.readValue(for: currentCharacteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            print("ERROR didUpdateValue \(e)")
            return
        }
        guard let data = characteristic.value else { return }
        
        //send data to aws
        //print(data)
        let received = data.reversed().reduce(0, { $0 << 8 | UInt32($1) })
        var doubleResult = Double(received)
        doubleResult = doubleResult/100
        let result = String(doubleResult)
        
        //print(ResultsList)

        if characteristic.uuid == CBUUID(string: TEMPERATURE_CHARACTERISTIC) {
            ResultsList[0] = result
        }
        else if characteristic.uuid == CBUUID(string: HUMIDITY_CHARACTERISTIC) {
            ResultsList[1] = result
        }
        else if characteristic.uuid == CBUUID(string: PRESSURE_CHARACTERISTIC) {
            ResultsList[2] = result
        }
    } //end func
    
    func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        shadowView.isHidden = true
    }
    
    func hasConnected() {
        activityIndicator.stopAnimating()
        shadowView.isHidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        //Dispose of any resource that can be recreated
    }
    
    // Central Manager Delegaters
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralManagerDidUpdateState: started!")
        
        switch (central.state) {
            case .poweredOff:
                print("Bluetooth is powered off")
                break
                
            case .resetting:
                print("Resetting")
                break
            
            case .poweredOn:
                print("Bluetooth is powered ON")
                break
                
            case .unauthorized:
                print("Unauthorized")
                break
            
            case .unsupported:
                print("Unsupported")
                break
                
            default:
                print("Unknown")
                break
        } // end of switch statement
    } // end of func
    
} //end of class

// extension to String (THIS EXTENSION IS NOT MY CODE)
extension String {
    
    /// Create NSData from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a NSData object. Note, if the string has any spaces, those are removed. Also if the string started with a '<' or ended with a '>', those are removed, too. This does no validation of the string to ensure it's a valid hexadecimal string
    ///
    /// The use of `strtoul` inspired by Martin R at http://stackoverflow.com/a/26284562/1271826
    ///
    /// - returns: NSData represented by this hexadecimal string. Returns nil if string contains characters outside the 0-9 and a-f range.
    
    func dataFromHexadecimalString() -> Data? {
        let trimmedString = self.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")).replacingOccurrences(of: " ", with: "")
        
        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them
        
        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .caseInsensitive)
        
        let found = regex.firstMatch(in: trimmedString, options: [], range: NSMakeRange(0, trimmedString.count))
        if found == nil || found?.range.location == NSNotFound || trimmedString.count % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
        
        let data = NSMutableData(capacity: trimmedString.count / 2)
        
        var index = trimmedString.startIndex
        while index < trimmedString.endIndex {
            let byteString = String(trimmedString[index ..< trimmedString.index(after: trimmedString.index(after: index))])
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.append([num] as [UInt8], length: 1)
            index = trimmedString.index(after: trimmedString.index(after: index))
        }
        
        //        for var index = trimmedString.startIndex; index < trimmedString.endIndex; index = trimmedString.index(after: trimmedString.index(after: index)) {
        //            let byteString = trimmedString.substring(with: (index ..< trimmedString.index(after: trimmedString.index(after: index))))
        //            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
        //            data?.append([num] as [UInt8], length: 1)
        //        }
        
        return data as Data?
    }
}

