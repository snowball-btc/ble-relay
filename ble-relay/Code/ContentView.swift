//
//  ContentView.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/1/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
    
        NavigationView {
            FormView()
        }
    }
}

struct FormView : View {
    @EnvironmentObject var model: Model
    
    var centralRelay = CentralRelay()
    
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
                    self.centralRelay.setToEleven() // DEBUG: Remove later
                // TODO: Start sending packets, fire up the correct manager based on toggle button
                }) { Text("Start")}
            }
            
            Section {
                HStack {
                    Text("Status:")
                    Text("Connected")
                }
            }
            
            Section {
                Toggle(isOn: $model.peripheralMode) {
                    Text("Peripheral Mode")
                }
            }
            
            Section {
                NavigationLink(destination: Log()) {
                    // TODO: put log of BLE events here
                    Text("View Log")

                }
            }
        }.navigationBarTitle(Text("BLE Relay"))
    }
}

struct Log : View {
    var body: some View {
        Text("LOG HERE TBD")
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
