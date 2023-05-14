//
//  CustomImagePicker.swift
//  SwiftUI_ImageCroppingProject
//
//  Created by Noice_anas on 15/05/2023.
//

import SwiftUI
import PhotosUI

extension View {
    @ViewBuilder
    func cropImagePicker(options: [Crop], isPresented: Binding<Bool>, croppedImage: Binding<UIImage?>) -> some View {
        CustomImagePicker(options: options, isPresented: isPresented, croppedImage: croppedImage) {
            self
        }
    }
    
    // Haptic feedback
    func haptics(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    

}

struct CustomImagePicker<Content: View>: View {
    var content: Content
    var options: [Crop]
    @Binding var isPresented: Bool
    @Binding var croppedImage: UIImage?
    
    init(options: [Crop], isPresented: Binding<Bool>, croppedImage: Binding<UIImage?> ,@ViewBuilder content: @escaping () -> Content) {
        self.options = options
        self._isPresented = isPresented
        self._croppedImage = croppedImage
        self.content = content()
    }
    
    //View properties
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isPresentedDialog: Bool = false
    @State private var selectedCropRatio: Crop = .circle
    @State private var isPresentedCropView: Bool = false
    
    var body: some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $photosItem)
            .onChange(of: photosItem) { newValue in
//                Extracting UIImage from photosItem
                if let newValue {
                    Task {
                        if let imageData = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: imageData) {
                            await MainActor.run(body: {
                                selectedImage = image
                                isPresentedDialog = true
                            })
                        }
                    }
                }
            }
            .confirmationDialog("", isPresented: $isPresentedDialog) {
                //presenting all options
                ForEach(options.indices, id: \.self) { index in
                    Button(options[index].name()) {
                        selectedCropRatio = options[index]
                        isPresentedCropView = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresentedCropView) {
                //whenever sheet is dismissed set selection to nil
                selectedImage = nil
            } content: {
                CropView(crop: selectedCropRatio, image: selectedImage) { croppedImage, status in
                    //TODO: Add something
                    if let croppedImage {
                        self.croppedImage = croppedImage
                    }
                }
            }
    }
}


struct CropView: View {
    var crop: Crop
    var image: UIImage?
    var onCrop: (UIImage?, Bool) -> ()
    
    //View properties
    @Environment(\.dismiss) private var dismiss
    
//    Gesture Properties
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 0
    @State private var offset: CGSize = .zero
    @State private var lastStoredOffset: CGSize = .zero
    @GestureState private var isInteracting: Bool = false
    
    var body: some View {
        NavigationStack {
            ImageView()
            //Navigation bar thingees
                .navigationTitle("Crop View")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            //Navigation bar thingees
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Converting View to Image, Only on iOS 16 and above
                            let renderer = ImageRenderer(content: ImageView(hideGrid: true))
                            renderer.proposedSize = .init(crop.size())
                            if let image = renderer.uiImage{
                                onCrop(image, true)
                            } else {
                                onCrop(nil, false)
                            }
                            
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.white)
                            
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.white)
                            
                        }
                    }
                }
                
            
        }
    }
    
    //Image View
    @ViewBuilder
    func ImageView(hideGrid: Bool = false) -> some View {
        let cropSize = crop.size()
        
        GeometryReader {
            let size = $0.size
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay {
                        GeometryReader { proxy in
                            let rect = proxy.frame(in: .named("CROPVIEW"))
                            
                            Color.clear
                                .onChange(of: isInteracting) { newValue in
                                    /// - true  dragging
                                    /// - false stopped dragging
                                    /// - with the help of GeometryReader we can read min x,y and max x,y values of the image
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if rect.minX > 0 {
                                            /// - Resetting to last location
                                            offset.width = (offset.width - rect.minX)
                                            haptics(.medium)
                                        }
                                        if rect.minY > 0 {
                                            /// - Resetting to last location
                                            offset.height = (offset.height - rect.minY)
                                            haptics(.medium)
                                        }
                                        if rect.maxX < size.width {
                                            /// - Resetting to last location
                                            offset.width = (rect.minX - offset.width)
                                            haptics(.medium)
                                        }
                                        if rect.maxY < size.height {
                                            /// - Resetting to last location
                                            offset.height = (rect.minY - offset.height)
                                            haptics(.medium)
                                        }
                                    }
                                    if !newValue {
                                        /// - Storing last offset
                                        lastStoredOffset = offset
                                    }
                                }
                        }
                    }
                    .frame(width: size.width, height: size.height)
                   
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .overlay {
            if !hideGrid {
                Grids()
            }
        }
        .coordinateSpace(name: "CROPVIEW")
        .gesture(
            DragGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                })
                .onChanged({ value in
                    let translation = value.translation
                    offset = CGSize(width: translation.width + lastStoredOffset.width, height: translation.height + lastStoredOffset.height)
                })
        )
        .gesture(
            MagnificationGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                })
                .onChanged({ value in
                    let updateScale = value + lastScale
                    /// - limiting beyond 1
                    scale = (updateScale < 1 ? 1 : updateScale)
                })
                .onEnded({ value in
                    withAnimation(.easeIn(duration: 0.2)) {
                        if scale < 1 {
                            scale = 1
                            lastScale = 0
                        } else {
                            lastScale = scale - 1
                        }
                    }
                })
        )
        .frame(width: cropSize.width, height: cropSize.height)
        .cornerRadius(crop == .circle ? cropSize.height / 2 : 0)
    }
    
    /// - Grids
    @ViewBuilder
    func Grids() -> some View {
        ZStack {
            HStack {
                ForEach(1..<5 , id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity (0.7))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            
            VStack {
                ForEach(1..<8 , id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity (0.7))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
    
}



struct CustomImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        CropView(crop: .rectangle, image: UIImage(named: "Pondering man")) { _, _ in
            
        }
    }
}
