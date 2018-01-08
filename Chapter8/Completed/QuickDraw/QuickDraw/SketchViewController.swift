//
//  SketchViewController.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 27/12/2017.
//  Copyright © 2017 Method. All rights reserved.
//

import UIKit
import CoreVideo

class SketchViewController: UIViewController {
    
    enum SketchMode{
        case sketch, move, dispose
    }

    fileprivate let reuseIdentifier = "SketchPreviewCell"
    
    fileprivate let sectionInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var toolBarLabel: UILabel!
    
    @IBOutlet weak var sketchView: SketchView!
    
    @IBOutlet weak var sketchModeButton: UIButton!
    
    @IBOutlet weak var moveModeButton: UIButton!
    
    @IBOutlet weak var disposeModeButton: UIButton!
    
    let ciContext = CIContext()
    
    let queryFacade = QueryFacade()
    
    var queryImages = [UIImage]()
    
    var mode : SketchMode = .sketch{
        didSet{
            onSketchModeChanged()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sketchView.addTarget(self, action: #selector(SketchViewController.onSketchViewEditingDidEnd), for: .editingDidEnd)
        
        queryFacade.delegate = self 
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)                        
    }
}

// MARK: - Editing actions from the SketchView

extension SketchViewController{
    @objc func onSketchViewEditingDidEnd(_ sender:SketchView){
        guard self.sketchView.currentSketch != nil,
            let sketch = self.sketchView.currentSketch as? StrokeSketch else{
            return
        }
        
//        if let uiImage = UIImage(named:"test_img_airplane_1"){
//            let ciImage = CIImage(cgImage: uiImage.cgImage!)
//            if let predictions = queryFacade.classifySketch(image: ciImage.resize(size: CGSize(width: 256, height: 256))){
//                for (key, value) in predictions{
//                    print("\(key) \(value)")
//                }
//            }
//
//        }
        
        // send sketch to our query facade which will
        // perform classification on it and then
        // proceed to search and download the related images
        // (notifying us via the delegate method when finished)
        queryFacade.asyncQuery(sketch: sketch)
    }
    
    fileprivate func onSketchModeChanged(){
        // update UI
        self.sketchModeButton.isSelected = self.mode == .sketch
        self.moveModeButton.isSelected = self.mode == .move
        self.disposeModeButton.isSelected = self.mode == .dispose
        
        self.sketchView.isEnabled = self.mode == .sketch
        
        if self.mode == SketchMode.dispose{
            // remove any suggested images
            self.queryImages.removeAll()
            self.collectionView.reloadData()
            self.toolBarLabel.isHidden = queryImages.count == 0
            
            // remove all sketches from sketchview
            self.sketchView.removeAllSketches()
            
            // switch back to the default mode (sketch)
            self.mode = .sketch
        }
    }
}

// MARK: - UICollectionViewDataSource

extension SketchViewController : UICollectionViewDataSource{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return queryImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath) as! SketchPreviewCell
        
        cell.imageView.image = queryImages[indexPath.row]
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension SketchViewController : UICollectionViewDelegate{
    func collectionView(_ collectionView: UICollectionView,
                             didSelectItemAt indexPath: IndexPath)
    {
        guard let sketch = self.sketchView.currentSketch else{
            return
        }
        
        let image = self.queryImages[indexPath.row]
        let bbox = sketch.boundingBox
        
        var origin = CGPoint(x:0, y:0)
        var size = CGSize(width:0, height:0)
        
        if bbox.size.width > bbox.size.height{
            let ratio = image.size.height / image.size.width
            size.width = bbox.size.width
            size.height = bbox.size.width * ratio
        } else{
            let ratio = image.size.width / image.size.height
            size.width = bbox.size.height * ratio
            size.height = bbox.size.height
        }
        
        origin.x = sketch.center.x - size.width / 2
        origin.y = sketch.center.y - size.height / 2
        
        // swap out stroke sketch with image
        self.sketchView.currentSketch = ImageSketch(image:image,
                                                    origin:origin,
                                                    size:size,
                                                    label:"")
        
        // clear suggestions
        self.queryImages.removeAll()
        self.toolBarLabel.isHidden = queryImages.count == 0
        self.collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SketchViewController : UICollectionViewDelegateFlowLayout{
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let paddingSpace = sectionInsets.top + sectionInsets.bottom
        let cellDim = collectionView.frame.height - paddingSpace
        
        return CGSize(width: cellDim, height: cellDim)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
}

// MARK: - QueryDelegate

extension SketchViewController : QueryDelegate{

    func onQueryCompleted(status: Int, result:QueryResult?){
        print("onQueryCompleted \(status)")
        
        queryImages.removeAll()
        
        if let result = result{
            for cimage in result.images{
                if let cgImage = self.ciContext.createCGImage(cimage, from:cimage.extent){
                    queryImages.append(UIImage(cgImage:cgImage))
                }
            }
        }
        
        toolBarLabel.isHidden = queryImages.count == 0
        collectionView.reloadData() 
    }
    
}

// MARK: - Interface Builder Actions

extension SketchViewController{
    
    @IBAction func onPenTapped(_ sender: Any) {
        self.mode = .sketch
    }
    
    @IBAction func onMoveTapped(_ sender: Any) {
        self.mode = .move
    }
    
    @IBAction func onDisposeTapped(_ sender: Any) {
        self.mode = .dispose
    }
}
