//
//  ViewController.swift
//  LanguageTutor
//
//  Created by Joshua Newnham on 28/11/2017.
//  Copyright © 2017 Josh Newnham. All rights reserved.
//

import UIKit
import CoreVideo
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var previewView:CapturePreviewView!
    @IBOutlet var classifiedLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
                      
    }
}

// MARK: - VideoCaptureDelegate

extension ViewController : VideoCaptureDelegate{
    
    func onFrameCaptured(videoCapture: VideoCapture, pixelBuffer:CVPixelBuffer?, timestamp:CMTime){
        
    }
}

