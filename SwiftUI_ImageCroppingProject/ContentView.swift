//
//  ContentView.swift
//  SwiftUI_ImageCroppingProject
//
//  Created by Noice_anas on 14/05/2023.
//

import SwiftUI

struct ContentView: View {
    // View Properties
    @State private var showPicker: Bool = false
    @State private var croppedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack {
                if let croppedImage {
                    Image(uiImage: croppedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300)
                    
                } else {
                    Text("No Image has been chosen")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Crop Image Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Text("Add Image")
                    }
                }
            }
            .cropImagePicker(options: [.circle, .rectangle, .square], isPresented: $showPicker, croppedImage: $croppedImage)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
