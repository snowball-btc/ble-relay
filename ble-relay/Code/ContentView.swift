//
//  ContentView.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/1/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import RxBluetoothKit
import SwiftUI

struct ContentView: View {
    var body: some View {
    
        NavigationView {
            FormView()
        }
    }
}

struct FormView: View {
    @EnvironmentObject var model: Model
    
//    var centralRelay = CentralRelay()
//    var peripheralRelay = PeripheralRelay()
    
    var bluetoothService = RxBluetoothKitService()
    
    var body: some View {

        Form {
            Section {
                HStack {
                    Text("Value:")
                    Text("\(model.count)")
                }
            }
            
            Section {
                Button(action: {
                    
                    if self.model.peripheralMode {
//                        self.peripheralRelay.start()
                    } else {
                        self.bluetoothService.startScanning()
                    }
                }) { Text("SStart")
                }
            }
            
            Section {
                HStack {
                    Text("Status:")
                    Text(model.status)
                }
                VStack {
                    Toggle(isOn: $model.peripheralMode) {
                        Text("Peripheral Mode")
                    }
                    NavigationLink(destination: Log()) {
                        // TODO: put log of BLE events here
                        Text("View Log")
                    }
                }
            }
        }.navigationBarTitle(Text("BLE Relay"))
    }
}

struct Log: View {
    var body: some View {
        Text("LOG HERE TBD")
    }
}

#if DEBUG
struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
