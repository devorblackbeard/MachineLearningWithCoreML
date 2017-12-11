//
//  VideoCapture.swift
//  LanguageTutor
//
//  Created by Joshua Newnham on 29/11/2017.
//  Copyright © 2017 Josh Newnham. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo 

public protocol VideoCaptureDelegate: class {
    func onFrameCaptured(videoCapture: VideoCapture, pixelBuffer:CVPixelBuffer?, timestamp:CMTime)
}

/**
 Class used to faciliate accessing each frame of the camera using the AVFoundation framework (and presenting
 the frames on a preview view)
 https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput
 */
public class VideoCapture : NSObject{
    public weak var delegate: VideoCaptureDelegate?
    
    /**
     Frames Per Second; used to throttle capture rate
    */
    public var fps = 15
    
    var lastTimestamp = CMTime()
    
    override init() {
        super.init()
        
    }
    
    public func asyncInit(completion: @escaping (Bool) -> Void){
        
    }
    
    private func initCamera() -> Bool{
        return true
    }
    
    /**
     Start capturing frames
     This is a blocking call which can take some time, therefore you should perform session setup off
     the main queue to avoid blocking it.
    */
    public func startCapturing(){
        
    }
    
    /**
     Stop capturing frames
    */
    public func stopCapturing(){
        
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCapture : AVCaptureVideoDataOutputSampleBufferDelegate{
    
    /**
     Called when a new video frame was written
    */
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let delegate = self.delegate else{ return }
        
        // Returns the earliest presentation timestamp of all the samples in a CMSampleBuffer
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Throttle capture rate based on assigned fps
        let elapsedTime = timestamp - lastTimestamp
        if elapsedTime >= CMTimeMake(1, Int32(fps)) {
            // update timestamp
            lastTimestamp = timestamp
            // get sample buffer's CVImageBuffer
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            // pass onto the assigned delegate
            delegate.onFrameCaptured(videoCapture: self, pixelBuffer:imageBuffer, timestamp: timestamp)
        }
    }
    
    /**
     Called when a frame is dropped
     */
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Ignore
    }
}
