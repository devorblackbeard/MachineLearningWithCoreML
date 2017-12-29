//
//  SketchViewController.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 27/12/2017.
//  Copyright © 2017 Method. All rights reserved.
//

import UIKit

protocol SketchViewControllerDelegate : class{
    func onSketchSelected(uiImage:UIImage?, boundingBox:CGRect?)
}

class SketchViewController: UIViewController {

    fileprivate let reuseIdentifier = "SketchPreviewCell"
    
    fileprivate let itemsPerRow: CGFloat = 2
    
    fileprivate let sectionInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var sketchView: SketchView!
    
    @IBOutlet weak var sketchLabel: UILabel!
    
    @IBOutlet weak var resultsLabel: UILabel!
        
    weak var delegate : SketchViewControllerDelegate?
    
    var classification : String?
    
    var bingSearchResults = [BingServiceResult]()
    
    var bingSearchCIImages = [CIImage]()
    
    var bingSearchUIImages = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.updateClassification(label:"boat")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sketchLabel.alpha = 1.0
        resultsLabel.alpha = 1.0
        
        UIView.animate(withDuration: 3.0) {
            self.sketchLabel.alpha = 0.0
            self.resultsLabel.alpha = 0.0
        }
    }
    
    @IBAction func onNavCancel(_ sender: Any) {
        dismiss(animated: true) {
            
        }
    }
}

// MARK: - UICollectionViewDataSource

extension SketchViewController{
    
    fileprivate func clearResults(){
        bingSearchResults.removeAll()
        bingSearchCIImages.removeAll()
        bingSearchUIImages.removeAll()
        
        self.collectionView.reloadData()
    }
    
    func updateClassification(label:String?){
        // any change?
        guard label != self.classification else{
            return
        }
        
        clearResults()
        
        // label is null
        guard let label = label else{
            self.classification = nil
            return
        }
        
        // perform a image search
        BingService.sharedInstance.search(searchTerm: label) { (status, results) in
            guard let results = results, status == 1 else{ return }
            
            for result in results{
                self.bingSearchResults.append(result)
            }
            
            // download images 
            self.downloadNextImage()
        }
    }
    
    func downloadNextImage(){
        if bingSearchResults.count == 0{
            sortImages()
        } else{
            let bingResult = bingSearchResults.remove(at:0)
            
            BingService.sharedInstance.downloadImage(bingResult:bingResult) { (status, filename, image) in
                guard let image = image, status == 1 else{ return }
                
                self.bingSearchCIImages.append(image)
                
                self.downloadNextImage()
            }
        }
    }
    
    func sortImages(){
        // TODO
        onImagesSorted()
    }
    
    func onImagesSorted(){
        for ciImage in self.bingSearchCIImages{
            bingSearchUIImages.append(UIImage(ciImage:ciImage))
        }
        
        self.collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension SketchViewController : UICollectionViewDataSource{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return bingSearchUIImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath) as! SketchPreviewCell
        
        cell.imageView.image = bingSearchUIImages[indexPath.row]
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension SketchViewController : UICollectionViewDelegate{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let bbox = self.sketchView.boundingBox
        let image = self.bingSearchUIImages[indexPath.row]
        self.delegate?.onSketchSelected(uiImage: image, boundingBox: bbox)
        
        dismiss(animated: true) {
            
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension SketchViewController : UICollectionViewDelegateFlowLayout{
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = collectionView.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return sectionInsets.left
    }
}
