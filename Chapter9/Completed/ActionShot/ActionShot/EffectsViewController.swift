//
//  EffectViewController.swift
//  ActionShot
//
//  Created by Joshua Newnham on 31/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import CoreImage

protocol EffectsViewControllerDelegate : class{
    func onEffectsViewDismissed(sender:EffectsViewController)
}

class EffectsViewController: UIViewController {
    
    /**
     Presents the image (stylized image if a style has been applied)
     */
    weak var imageView : UIImageView?
    
    weak var activityIndicatorView : UIActivityIndicatorView?
    
    weak var delegate : EffectsViewControllerDelegate?
    
    var frames  = [CIImage]()
    
    var isProgressingImage : Bool{
        get{
            guard let activityIndicatorView = self.activityIndicatorView else{
                return false
            }
            
            return !activityIndicatorView.isAnimating
        }
    }
    
    /**
     Utility class encapsulating methods for data pre-processing
     */
    //let imageProcessor : ImageProcessor = ImageProcessor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initUI()
        
        //imageProcessor.delegate = self
        
        self.processFrames()
    }
    
    private func processFrames(){
        // create and add a blur effect
        let effect = UIBlurEffect(style: .regular)
        let visualEffectsView = UIVisualEffectView(effect: effect)
        visualEffectsView.tag = 99
        visualEffectsView.frame = self.view.bounds
        visualEffectsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(visualEffectsView)
        
        if let activityIndicatorView = self.activityIndicatorView{
            self.view.bringSubview(toFront: activityIndicatorView)
            activityIndicatorView.startAnimating()
        }
        
        //self.imageProcessor.processImage(ciImage: contentImage)
    }
}

// MARK: - ImageProcessorDelegate

//extension EffectsViewController : ImageProcessorDelegate{
//
//    func onImageProcessorCompleted(status: Int, stylizedImage:CGImage?){
//        guard status > 0, let stylizedImage = stylizedImage else{
//            return
//        }
//
//        // Stop animating activity indiactor
//        self.activityIndicatorView?.stopAnimating()
//
//        // Remove blur
//        guard let effectView = self.view.viewWithTag(99) else { return }
//        effectView.removeFromSuperview()
//
//        // Update image
//        self.imageView?.image = UIImage(cgImage: stylizedImage)
//    }
//}

// MARK: - UI

extension EffectsViewController{
    
    func initUI(){
        let imageView = UIImageView(frame: CGRect(
            origin: self.view.bounds.origin,
            size: CGSize(width: self.view.bounds.width,
                         height: self.view.bounds.height)))
        self.view.addSubview(imageView)
        
        imageView.topAnchor.constraint(equalTo: self.view.topAnchor,
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
                              action: #selector(EffectsViewController.onCloseButtonTapped(_:)), for: .touchUpInside)
        
        let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicatorView.center = self.view.center
        activityIndicatorView.hidesWhenStopped = true
        view.addSubview(activityIndicatorView)
        self.activityIndicatorView = activityIndicatorView
    }
    
    @objc func onCloseButtonTapped(_ sender:UIButton){
        self.dismiss(animated: false) {
            self.delegate?.onEffectsViewDismissed(sender: self)
        }
    }
}
