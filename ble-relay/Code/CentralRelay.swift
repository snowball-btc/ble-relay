//
//  Relay.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/1/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import CoreBluetooth
import SwiftUI

class CentralRelay: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var remoteDevice: CBPeripheral?
    
    // Custom service and characteristic UUIDs generated using `$ uuidgen`
    let serviceUUID = CBUUID(string: "FDB424BE-4458-485A-9F43-1E7048B00ABB")
    let countCharacteristicUUID = CBUUID(string: "ADBE0057-4EC9-40EC-8C68-DC46C3853678")
        
    override init() {
        super.init()
        centralManager = CBCentralManager()
        centralManager.delegate = self
    }

    // MARK: Central manager delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        remoteDevice = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    // MARK: Peripheral delegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) {
            peripheral.discoverCharacteristics([countCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == countCharacteristicUUID}) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // TODO: React accordingly
    }
    
    // DEBUG: Remove later
    func setToEleven() {
        model.count = 11
    }
}
