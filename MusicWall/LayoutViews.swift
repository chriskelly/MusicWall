//
//  LayoutView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/1/25.
//

import SwiftUI

struct LayoutMenu: View {
    @Binding var currentLayout: Option
    
    enum Option: String, CaseIterable, Identifiable, Codable {
        var id: String { rawValue }
        
        case grid = "grid"
        case list = "list"
    }
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    @Previewable @State var layout: LayoutMenu.Option = .grid
    LayoutMenu(currentLayout: $layout)
}
