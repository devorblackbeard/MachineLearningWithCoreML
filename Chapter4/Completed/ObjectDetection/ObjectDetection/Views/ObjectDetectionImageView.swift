//
//  SearchResultImageView.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 14/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit

protocol ObjectDetectionImageViewDelegate : class {
    func onObjectDetectionImageViewDismissed(view:ObjectDetectionImageView)
}

class ObjectDetectionImageView : UIControl{
    
    weak var delegate : ObjectDetectionImageViewDelegate?
    
    var searchResult : SearchResult?{
        didSet{
            self.setNeedsDisplay()
        }
    }
    
    var fromFrame : CGRect?
    
    var toFrame : CGRect?
    
    var tapGestureRecognizer : UITapGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(ObjectDetectionImageView.onTapGestureDetected))
        
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.isEnabled = false
        addGestureRecognizer(tapGestureRecognizer)
        
        self.tapGestureRecognizer = tapGestureRecognizer
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @objc func onTapGestureDetected() {
        self.hide()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        context.setFillColor(UIColor.white.cgColor)
        context.addRect(self.bounds)
        context.drawPath(using: .fill)
        
        guard let searchResult = self.searchResult else {
            return
        }
        
        self.drawImage(context: context, targetRect: rect, image: searchResult.image)
        
        let tmp = CGRect(x: 0, y: 0, width: 416, height: 416)
        searchResult.image.draw(in: tmp)
        
        for detectedObject in searchResult.detectedObjects{
            self.drawDetectedObject(context:context,
                                    rect:rect,
                                    detectedObject:detectedObject,
                                    imageSize:tmp.size) // searchResult.image.size)
        }
    }
    
    /**
     Aspect fit fill
    **/
    private func drawImage(context:CGContext, targetRect:CGRect, image:UIImage){
        let aspect = image.size.width / image.size.height
        let rect: CGRect
        if targetRect.size.width / aspect > targetRect.size.height {
            let height = targetRect.size.width / aspect
            rect = CGRect(x: 0, y: (targetRect.size.height - height) / 2,
                          width: targetRect.size.width, height: height)
        } else {
            let width = targetRect.size.height * aspect
            rect = CGRect(x: (targetRect.size.width - width) / 2, y: 0,
                          width: width, height: targetRect.size.height)
        }
        
        image.draw(in: rect)
    }
    
    private func drawDetectedObject(context:CGContext, rect:CGRect, detectedObject:ObjectBounds, imageSize:CGSize){
        
        // scale bounds
        let bounds = CGRect(x: detectedObject.origin.x * imageSize.width,
                            y: detectedObject.origin.y * imageSize.height,
                            width: detectedObject.size.width * imageSize.width,
                            height: detectedObject.size.height * imageSize.height)
        
        let color = DetectableObject.getColor(classIndex:detectedObject.object.classIndex)
        
        // Set up some generic parameters used for both, drawing the bounds and rectangle
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        
        // Draw rect
        context.addRect(bounds)
        context.drawPath(using: .stroke)
        
        // Draw label
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attrs = [NSAttributedStringKey.font: UIFont(name: "HelveticaNeue-Thin", size: 16)!, NSAttributedStringKey.paragraphStyle: paragraphStyle]
        
        let label = NSString(string: detectedObject.object.label)
        let stringBounds = label.boundingRect(with: bounds.size, options: [], attributes: attrs, context: nil)
        let labelBounds = CGRect(x: bounds.origin.x,
                                 y: bounds.origin.y - stringBounds.size.height,
                                 width: stringBounds.size.width,
                                 height: stringBounds.size.height)
        context.addRect(labelBounds)
        context.drawPath(using: .fillStroke)
        
        context.setStrokeColor(UIColor.white.cgColor)
        label.draw(in: labelBounds, withAttributes: attrs)
    }
    
    func show(searchResult:SearchResult, from:CGRect, to:CGRect){
        self.searchResult = searchResult
        self.fromFrame = from
        self.toFrame = to
        
        self.alpha = 0.0
        self.isHidden = false
        self.isUserInteractionEnabled = true
        self.tapGestureRecognizer?.isEnabled = true
        self.frame = self.fromFrame!
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0.0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.2,
            options: [],
            animations: {
                self.alpha = 1.0
                self.frame = self.toFrame!
        }, completion: { (completed) in
            self.setNeedsDisplay()
        })
    }
    
    func hide(){
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0.0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.2,
            options: [],
            animations: {
                self.alpha = 0.0
                self.frame = self.fromFrame!
        }, completion: { (completed) in
            self.isHidden = true
            self.tapGestureRecognizer?.isEnabled = false
            self.isUserInteractionEnabled = false
            
            self.setNeedsDisplay()
            
            self.delegate?.onObjectDetectionImageViewDismissed(view: self)
        })
    }
}
