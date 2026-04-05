//
//  Lap_Widget_ExtensionBundle.swift
//  Lap​Widget​Extension
//
//  Created by 賈博文 on 2026/04/04.
//

import WidgetKit
import SwiftUI

@main
struct Lap_Widget_ExtensionBundle: WidgetBundle {
    var body: some Widget {
        Lap_Widget_Extension()
        Lap_Widget_ExtensionControl()
        Lap_Widget_ExtensionLiveActivity()
    }
}
