//: Playground - noun: a place where people can play

import Cocoa
import AudioToolbox

let url = [#FileReference(fileReferenceLiteral: "baah.wav")#]
let violinUrl = [#FileReference(fileReferenceLiteral: "violin.wav")#]

//allocate the audio file ref and open it with the sheep URL
var af = ExtAudioFileRef()
var err: OSStatus = ExtAudioFileOpenURL(url as CFURL, &af)
guard err == noErr else {
    fatalError("unable to open extAudioFile: \(err)")
}

//allocate an empty ASBD
var fileASBD = AudioStreamBasicDescription()

//get the ASBD from the file
var size = UInt32(sizeofValue(fileASBD))
err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileDataFormat, &size, &fileASBD)
guard err == noErr else {
    fatalError("unable to get file data format: \(err)")
}

//set the ASBD to be used
err = ExtAudioFileSetProperty(af, kExtAudioFileProperty_ClientDataFormat, size, &fileASBD)
guard err == noErr else {
    fatalError("unable to set client data format: \(err)")
}

//check the number of frames expected
var numberOfFrames: Int64 = 0
var propertySize = UInt32(sizeof(Int64))
err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileLengthFrames, &propertySize, &numberOfFrames)
guard err == noErr else {
    fatalError("unable to get number of frames expected: \(err)")
}

//initialize a buffer and a place to put the final data
let bufferFrames = 4096
var data = [Float](count: bufferFrames, repeatedValue: 0)
let dataSize = sizeof(Float) * bufferFrames
var finalData = [Float]()

//pack all this into a buffer list
var bufferList = AudioBufferList(
    mNumberBuffers: 1,
    mBuffers: AudioBuffer(
        mNumberChannels: 2,
        mDataByteSize: UInt32(data.count),
        mData: &data
    )
)

//commented out things I was working with to output the file
//
//var outputAF = ExtAudioFileRef()
//let docsPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first
//let filePath = docsPath!.stringByAppendingString("file.wav")
//let outputURL = NSURL(fileURLWithPath: filePath)
//err = ExtAudioFileCreateWithURL(outputURL, kAudioFileWAVEType, &fileASBD, nil, AudioFileFlags.EraseFile.rawValue, &outputAF)
//guard err == noErr else {
//    fatalError("unhelpful error code is \(err)")
//}

//read the data
var count: UInt32 = 0
var ioFrames: UInt32 = 4096
while ioFrames > 0 {
    err = ExtAudioFileRead(af, &ioFrames, &bufferList)
    
    guard err == noErr else {
        fatalError("error reading the data: \(err)")
    }
    
    count += ioFrames
    finalData += data
}

//dispose of the file
err = ExtAudioFileDispose(af)
guard err == noErr else {
    fatalError("another error code \(err)")
}
