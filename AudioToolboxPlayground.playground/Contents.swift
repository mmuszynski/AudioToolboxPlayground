//: Playground - noun: a place where people can play

import Cocoa
import AudioToolbox
import Accelerate

let url = [#FileReference(fileReferenceLiteral: "baah.wav")#]
let violinUrl = [#FileReference(fileReferenceLiteral: "violin.wav")#]
let donkey = [#FileReference(fileReferenceLiteral: "donkey.mp3")#]
//allocate the audio file ref and open it with the sheep URL
var af = ExtAudioFileRef()
var err: OSStatus = ExtAudioFileOpenURL(donkey as CFURL, &af)
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

var clientASBD = AudioStreamBasicDescription()
clientASBD.mSampleRate = fileASBD.mSampleRate
clientASBD.mFormatID = kAudioFormatLinearPCM
clientASBD.mFormatFlags = kAudioFormatFlagsNativeFloatPacked
clientASBD.mBytesPerPacket = 4
clientASBD.mFramesPerPacket = 1
clientASBD.mBytesPerFrame = 4
clientASBD.mChannelsPerFrame = 1
clientASBD.mBitsPerChannel = 32

//set the ASBD to be used
err = ExtAudioFileSetProperty(af, kExtAudioFileProperty_ClientDataFormat, size, &clientASBD)
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
//var finalData = [Float]()

let dataPtr = UnsafeMutablePointer<Float>(malloc(bufferFrames * sizeof(Float.self)))
let finalData = UnsafeMutablePointer<Float>(malloc(Int(numberOfFrames) * sizeof(Float.self)))

//pack all this into a buffer list
var bufferList = AudioBufferList(
    mNumberBuffers: 1,
    mBuffers: AudioBuffer(
        mNumberChannels: 2,
        mDataByteSize: UInt32(data.count),
        mData: dataPtr
    )
)

//read the data
var count: UInt32 = 0
var ioFrames: UInt32 = 4096
while count == 0 {
    err = ExtAudioFileRead(af, &ioFrames, &bufferList)
    
    guard err == noErr else {
        fatalError("error reading the data: \(err)")
    }
    
    count += ioFrames
    //here???
    //finalData += UnsafeBufferPointer<Float>(start: dataPtr, count: 4096)
}

//dispose of the file
err = ExtAudioFileDispose(af)
guard err == noErr else {
    fatalError("another error code \(err)")
}

//fft operations
let frames = 4096
let length = vDSP_Length(log2(CDouble(frames)))
let setup = vDSP_create_fftsetup(length, FFTRadix(kFFTRadix2));

var outReal = [Float](count: frames/2, repeatedValue: 0)
var outImag = [Float](count: frames/2, repeatedValue: 0)
var out = COMPLEX_SPLIT(realp: &outReal, imagp: &outImag)

var dataAsComplex = UnsafePointer<COMPLEX>(finalData)

vDSP_ctoz(dataAsComplex, 2, &out, 1, UInt(frames/2))
vDSP_fft_zip(setup, &out, 1, length, Int32(FFT_FORWARD))
