//
//  Model.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/6/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Combine
import SwiftUI

final class Model: ObservableObject {
    @Published var peripheralMode = true
    @Published var count = 0
}
