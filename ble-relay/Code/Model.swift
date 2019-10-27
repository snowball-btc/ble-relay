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
    @Published var count = 0
    @Published var status = "Idle"
    @Published var connectedService = ""
    @Published var connectedPeripheral = ""
    
    // Custom service and characteristic UUIDs generated using `$ uuidgen`
    let serviceUUID = CBUUID(string: "FDB424BE-4458-485A-9F43-1E7048B00ABB")
    let countCharacteristicUUID = CBUUID(string: "ADBE0057-4EC9-40EC-8C68-DC46C3853678")
    let countCharacteristicName = "count"

    let goodRSSISignalStrength = -60    // Good or better signal strength is -60 dBm or higher
}
