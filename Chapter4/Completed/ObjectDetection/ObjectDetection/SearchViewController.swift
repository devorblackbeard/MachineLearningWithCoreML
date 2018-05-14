//
//  ViewController.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 13/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController {

    var searchInputView : SearchInputView?
    
    var iconImages = [(image:UIImage, selectedImage:UIImage)]()
    
    var iconButtonSize : CGSize?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initUI()
    }

}

// MARK: - User Interface

extension SearchViewController{
    
    func initUI(){
        
        // Collection view for object selection
        for i in 0..<DetectableObject.objects.count{
            let imageSrc = DetectableObject.objects[i].label
            let selectedImageSrc = "\(DetectableObject.objects[i].label)_selected"
            
            guard let image = UIImage(named: imageSrc),
                let selectedImage = UIImage(named:selectedImageSrc) else{
                fatalError("\(imageSrc) is not available")
            }
            
            self.iconImages.append((
                image: image,
                selectedImage: selectedImage))
            
            if iconButtonSize == nil{
                iconButtonSize = CGSize(width: self.view.bounds.width * 0.2,
                                        height: self.view.bounds.width * 0.2 * (image.size.height/image.size.width))
            }
        }
        
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionViewLayout.itemSize = CGSize(width: iconButtonSize!.width,
                                               height: iconButtonSize!.height)
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: CGRect(x: 0,
                                                            y: self.view.bounds.height-iconButtonSize!.height,
                                                            width: self.view.bounds.width,
                                                            height: iconButtonSize!.height),
                                              collectionViewLayout: collectionViewLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor.clear
        collectionView.register(IconViewCell.self, forCellWithReuseIdentifier: "IconViewCell")
        self.view.addSubview(collectionView)
        collectionView.reloadData()
        
        // Create label
        let labelSize = CGSize(width: self.view.bounds.width,
                               height: self.view.bounds.height * 0.1)
        let labelOrigin = CGPoint(x: self.view.bounds.origin.x + self.view.bounds.width * 0.025,
                                  y: self.view.bounds.origin.y + self.view.bounds.height * 0.05)
        let label = UILabel(frame: CGRect(origin: labelOrigin, size: labelSize))
        label.font = label.font.withSize(32)
        label.text = "Hello world"
        self.view.addSubview(label)
                
        // Create SearchInputView
        let searchViewSize = CGSize(width: self.view.bounds.width - (self.view.bounds.width * 0.05),
                                    height: self.view.bounds.width - (self.view.bounds.width * 0.05))
        let searchViewOrigin = CGPoint(x: (self.view.bounds.width / 2) - (searchViewSize.width / 2),
                                       y: labelOrigin.y + labelSize.height)
        
        let searchInputView = SearchInputView(frame: CGRect(
            origin: searchViewOrigin,
            size: searchViewSize))
        self.view.addSubview(searchInputView)
            
        searchInputView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        searchInputView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        
        self.searchInputView = searchInputView
        
        // Create undo and search button
        
        
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate

extension SearchViewController : UICollectionViewDataSource, UICollectionViewDelegate{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return DetectableObject.objects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IconViewCell", for: indexPath) as! IconViewCell
        let idx = indexPath.row
        cell.image = self.iconImages[idx].image
        cell.selectedImage = self.iconImages[idx].selectedImage
        cell.index = idx
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool{
        let cell = collectionView.cellForItem(at: indexPath) as! IconViewCell
        return !cell.isSelected
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath){
        let idx = indexPath.row
        self.searchInputView?.selectedDetectableObject = DetectableObject.objects[idx]
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath){
        self.searchInputView?.selectedDetectableObject = nil
    }
}


