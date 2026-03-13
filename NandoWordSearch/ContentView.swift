//
//  ContentView.swift
//  NandoWordSearch
//
//  Created by Fernando De Leon on 13/3/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ThemeSelectionView()
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
