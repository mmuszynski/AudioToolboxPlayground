//: Playground - noun: a place where people can play

import Cocoa
import AudioToolbox

let url = [#FileReference(fileReferenceLiteral: "baah.wav")#]
let violinUrl = [#FileReference(fileReferenceLiteral: "violin.wav")#]

var af = ExtAudioFileRef()
var err: OSStatus = ExtAudioFileOpenURL(url as CFURL, &af)
guard err == noErr else {
    fatalError("freak out error \(err)")
}

var clientASBD = AudioStreamBasicDescription(
    mSampleRate: 44100,
    mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: 9,
    mBytesPerPacket: 2,
    mFramesPerPacket: 1,
    mBytesPerFrame: 2,
    mChannelsPerFrame: 2,
    mBitsPerChannel: 8,
    mReserved: 0)

var fileASBD = AudioStreamBasicDescription()

var size = UInt32(sizeofValue(clientASBD))
err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileDataFormat, &size, &fileASBD)
guard err == noErr else {
    fatalError("another error code \(err)")
}

print(fileASBD)
err = ExtAudioFileSetProperty(af, kExtAudioFileProperty_ClientDataFormat, size, &fileASBD)


guard err == noErr else {
    fatalError("another error code \(err)")
}

var numberOfFrames: Int64 = 0
var propertySize = UInt32(sizeof(Int64))
err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileLengthFrames, &propertySize, &numberOfFrames)
guard err == noErr else {
    fatalError("another error code \(err)")
}

print(numberOfFrames)

let bufferFrames = 4000
var data = [Float](count: bufferFrames, repeatedValue: 0)
let dataSize = sizeof(Float) * bufferFrames
var finalData = [Float]()

var bufferList = AudioBufferList(
    mNumberBuffers: 1,
    mBuffers: AudioBuffer(
        mNumberChannels: 2,
        mDataByteSize: UInt32(data.count),
        mData: &data
    )
)

var outputAF = ExtAudioFileRef()
let docsPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first
let filePath = docsPath!.stringByAppendingString("file.wav")
let outputURL = NSURL(fileURLWithPath: filePath)
err = ExtAudioFileCreateWithURL(outputURL, kAudioFileWAVEType, &fileASBD, nil, AudioFileFlags.EraseFile.rawValue, &outputAF)
guard err == noErr else {
    fatalError("unhelpful error code is \(err)")
}

var count: UInt32 = 0
var ioFrames: UInt32 = 4000
while ioFrames > 0 {
    err = ExtAudioFileRead(af, &ioFrames, &bufferList)
    
    guard err == noErr else {
        fatalError("unhelpful error code is \(err)")
    }
    
    //err = ExtAudioFileWrite(outputAF, ioFrames, &bufferList)
    count += ioFrames
    finalData += data
}

print(finalData[0])

err = ExtAudioFileDispose(af)
guard err == noErr else {
    fatalError("another error code \(err)")
}
