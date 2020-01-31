//
//  Model.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/6/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Combine
import CoreBluetooth
import SwiftUI

final class Model: ObservableObject {
    @Published var peripheralMode = true
    @Published var countValue = 0
    @Published var status = "Idle"
    @Published var connectedService = ""
    @Published var connectedPeripheral = ""
    
    // NB: Custom service and characteristic UUIDs can be generated using `$ uuidgen`
    let serviceUUID = CBUUID(string: "FDB424BE-4458-485A-9F43-1E7048B00ABB")
    
    let count = CharacteristicModel(UUID: CBUUID(string: "ADBE0057-4EC9-40EC-8C68-DC46C3853678"), name: "count")
    let central = CharacteristicModel(UUID: CBUUID(string: "7343D676-5458-4136-96FB-2893FFC0C7BB"), name: "centralPublicKey")
    let peripheral = CharacteristicModel(UUID: CBUUID(string: "F0B45496-638B-4B42-86F6-9D7ED2D5ED2F"), name: "peripheralPublicKey")
    var privKey: String?
    var pubKey: String?
    
    let goodRSSISignalStrength = -60    // Good or better signal strength is -60 dBm or higher
}

struct CharacteristicModel {
    let UUID: CBUUID
    let name: String
}
