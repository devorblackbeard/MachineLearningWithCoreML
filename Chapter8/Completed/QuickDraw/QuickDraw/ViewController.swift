//
//  ViewController.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 21/12/2017.
//  Copyright © 2017 Method. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var canvasView: UIView!
    
    var draggingView : UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let panRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(ViewController.onPanGestureRecognizer))
        
        self.canvasView.gestureRecognizers = [panRecognizer]
    }
    
    @IBAction func onNavAdd(_ sender: Any) {
        guard let sketchVC = storyboard?.instantiateViewController(
            withIdentifier: "sketchVC") as? SketchViewController else { return }
                
        sketchVC.modalPresentationStyle = .overCurrentContext
        
        present(sketchVC, animated: true) {
            
        }
    }
}

// MARK: - UIPanGestureRecognizer

extension ViewController{
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else{
            return
        }
        
        let touchPoint = touch.location(in: self.canvasView)
        
        self.draggingView = nil
        
        for subview in self.canvasView.subviews{
            if subview.frame.contains(touchPoint){
                self.draggingView = subview
                self.self.canvasView.bringSubview(toFront: subview)
                break
            }
        }
    }
    
    @objc func onPanGestureRecognizer(gestureRecognizer:UIPanGestureRecognizer){
        guard let draggingView = self.draggingView else{ return }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            let translation = gestureRecognizer.translation(in: self.canvasView)
            
            draggingView.frame.origin = CGPoint(x: draggingView.frame.origin.x + translation.x,
                                                y: draggingView.frame.origin.y + translation.y)
            
            gestureRecognizer.setTranslation(CGPoint.zero, in: self.canvasView)
        } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled{
            self.draggingView = nil
        }
    }
    
}

