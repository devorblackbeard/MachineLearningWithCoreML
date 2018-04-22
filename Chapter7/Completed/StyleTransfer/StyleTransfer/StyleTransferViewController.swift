//
//  StyleTransferViewController.swift
//  StyleTransfer
//
//  Created by Joshua Newnham on 22/04/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import CoreImage

protocol StyleTransferViewControllerDelegate : class{
    func onStyleTransferViewDismissed(sender:StyleTransferViewController)
}

class StyleTransferViewController: UIViewController {
    
    /**
     Presents the image (stylized image if a style has been applied)
    */
    weak var imageView : UIImageView?
    
    weak var delegate : StyleTransferViewControllerDelegate?
    
    /**
     Content image that we will use as the input for our model
    */
    var contentImage : CIImage?{
        didSet{
            if let imageView = self.imageView,
                let contentImage = self.contentImage{
                imageView.image = UIImage(ciImage: contentImage)
            }
        }
    }
    
    /**
     Utility class encapsulating methods for data pre-processing
     */
    let imageProcessor : ImageProcessor = ImageProcessor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initUI()
        
        imageProcessor.delegate = self
    }
}

// MARK: - ImageProcessorDelegate

extension StyleTransferViewController : ImageProcessorDelegate{
    
    func onImageProcessorCompleted(status: Int, stylizedImage:CGImage?){
        guard status > 0, let stylizedImage = stylizedImage else{
            return
        }
        
        let imageView = UIImageView(frame:CGRect(x: 0, y: 0, width: 320, height: 320))
        imageView.image = UIImage(cgImage: stylizedImage)
        self.view.addSubview(imageView)
    }
}

// MARK: - UI

extension StyleTransferViewController{
    
    func initUI(){
        let imagesNames = [
            "van_cogh", "van_cogh_selected",
            "hokusai", "hokusai_selected",
            "andy_warhol", "andy_warhol_selected",
            "picasso", "picasso_selected"]
        
        for i in stride(from: 0, to: imagesNames.count, by: 2){
            let image = imagesNames[i]
            let imageSelected = imagesNames[i+1]
            
            
        }
        
        let imageView = UIImageView(frame: self.view.bounds)
        self.view.addSubview(imageView)
        
        imageView.topAnchor.constraint(equalTo: self.view.topAnchor,
                                         constant: 0).isActive = true
        imageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor,
                                            constant: 0).isActive = true
        imageView.leftAnchor.constraint(equalTo: self.view.leftAnchor,
                                          constant: 0).isActive = true
        imageView.rightAnchor.constraint(equalTo: self.view.rightAnchor,
                                           constant: 0).isActive = true
        
        self.imageView = imageView
        self.imageView?.contentMode = .scaleAspectFit
        
        // Close button
        let closeButtonImage = UIImage(named: "close_button")
        let closeButtonSize = CGSize(width: self.view.bounds.width * 0.05,
                                    height: self.view.bounds.width * 0.05 * (closeButtonImage!.size.height / closeButtonImage!.size.width))
        let closeButton = UIButton(frame:
            CGRect(x: closeButtonSize.width,
                   y: UIApplication.shared.statusBarFrame.height + (closeButtonSize.width * 0.5),
                   width: closeButtonSize.width,
                   height: closeButtonSize.height))
        self.view.addSubview(closeButton)
        closeButton.setImage(closeButtonImage, for: .normal)
        closeButton.addTarget(self,
                             action: #selector(StyleTransferViewController.onCloseButtonTapped(_:)), for: .touchUpInside)
        
        if let contentImage = self.contentImage{
            imageView.image = UIImage(ciImage:contentImage) 
        }
    }
    
    @objc func onCloseButtonTapped(_ sender:UIButton){
        self.dismiss(animated: false) {
            self.delegate?.onStyleTransferViewDismissed(sender: self)
        }
    }    
}


