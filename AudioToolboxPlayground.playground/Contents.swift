//: Playground - noun: a place where people can play

import Cocoa
import AudioToolbox
import Accelerate

let url = [#FileReference(fileReferenceLiteral: "baah.wav")#]
let violinUrl = [#FileReference(fileReferenceLiteral: "violin.wav")#]
let donkey = [#FileReference(fileReferenceLiteral: "donkey.mp3")#]
let tone100hz = [#FileReference(fileReferenceLiteral: "100hz44100.wav")#]

//allocate the audio file ref and open it with the sheep URL
var af = ExtAudioFileRef()
var err: OSStatus = ExtAudioFileOpenURL(tone100hz as CFURL, &af)
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

let sampleRate = fileASBD.mSampleRate

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

let length = Double(numberOfFrames) / sampleRate

//initialize a buffer and a place to put the final data
let bufferFrames = 4096
let finalData = UnsafeMutablePointer<Float>(malloc(Int(numberOfFrames) * sizeof(Float.self)))

//pack all this into a buffer list
var bufferList = AudioBufferList(
    mNumberBuffers: 1,
    mBuffers: AudioBuffer(
        mNumberChannels: 2,
        mDataByteSize: UInt32(sizeof(Float.self) * bufferFrames),
        mData: finalData
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
    
    bufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 2,
            mDataByteSize: UInt32(sizeofValue(finalData)),
            mData: finalData + Int(ioFrames)
        )
    )
    
    count += ioFrames
}

//dispose of the file
err = ExtAudioFileDispose(af)
guard err == noErr else {
    fatalError("another error code \(err)")
}

//fft operations
let frames = Int(numberOfFrames)
//let fft_length = vDSP_Length(log2(CDouble(frames)))
let fft_length: UInt = 16
let setup = vDSP_create_fftsetup(fft_length, FFTRadix(kFFTRadix2));

let outReal = UnsafeMutablePointer<Float>(malloc(Int(frames/2) * sizeof(Float.self)))
let outImag = UnsafeMutablePointer<Float>(malloc(Int(frames/2) * sizeof(Float.self)))

var out = COMPLEX_SPLIT(realp: outReal, imagp: outImag)
var dataAsComplex = UnsafePointer<COMPLEX>(finalData)

vDSP_ctoz(dataAsComplex, 2, &out, 1, UInt(frames/2))
vDSP_fft_zip(setup, &out, 1, fft_length, Int32(FFT_FORWARD))

let binSize = sampleRate / Double(frames)
let binFor1000 = 1000 / binSize

let power = UnsafeMutablePointer<Float>(malloc(Int(frames/2) * sizeof(Float.self)))
var highestPower:Float = 0
var x = 0

for i in 0..<frames/2 {
    power[i] = outReal[i] * outReal[i] + outImag[i] * outImag[i]
}

free(finalData)
free(outReal)
free(outImag)
