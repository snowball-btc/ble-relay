//
//  Result.swift
//  ble-relay
//
//  Created by Robert Baltzer on 10/19/19.
//  Copyright © 2019 Robert Baltzer. All rights reserved.
//

import Foundation

enum Result<T, E> {
    case success(T)
    case error(E)
}
