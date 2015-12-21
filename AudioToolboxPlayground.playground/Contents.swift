//: Playground - noun: a place where people can play

import Cocoa
import AudioToolbox
import Accelerate

enum FFTAnalyzerError: ErrorType {
    case GeneralError(OSStatus)
    case CouldNotResolveURL(OSStatus)
    case CouldNotGetAudioFileFormat(OSStatus)
    case CouldNotSetAudioFormat(OSStatus)
    case CouldNotGetAudioFileSize(OSStatus)
    case ErrorReadingAudioData(OSStatus)
    case BadFFTDataProduced
    
    func description() -> String {
        switch self {
        case .BadFFTDataProduced:
            return "Bad FFT data"
        case GeneralError(let status):
            return "An unknown error has occurred \(status)"
        case CouldNotGetAudioFileFormat(let status):
            return "Could not get Audio File Format: \(status)"
        case CouldNotSetAudioFormat(let status):
            return "Could not set Audio File Format: \(status)"
        case CouldNotGetAudioFileSize(let status):
            return "Could not get Audio File Size: \(status)"
        case ErrorReadingAudioData(let status):
            return "Error reading Audio Data: \(status)"
        case .CouldNotResolveURL(let status):
            return "Could not resolve URL \(status)"
        }
    }
}

class FFTAnalzer: NSObject {
    let url: NSURL
    var sampleRate: Double
    var audioData = [Float]()
    
    var fftSamples: Int
    var fftOutput = [Float]()
    
    init(url: NSURL, sampleRate rate: Double = 0, fftSamples samples: Int = 0) {
        self.url = url
        self.sampleRate = rate
        self.fftSamples = samples
    }
    
    func performAnalysis() throws {
        var af = ExtAudioFileRef()
        var err: OSStatus = ExtAudioFileOpenURL(url as CFURL, &af)
        guard err == noErr else {
            throw FFTAnalyzerError.CouldNotResolveURL(err)
        }
        af
        
        //allocate an empty ASBD
        var fileASBD = AudioStreamBasicDescription()
        
        //get the ASBD from the file
        var size = UInt32(sizeofValue(fileASBD))
        err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileDataFormat, &size, &fileASBD)
        guard err == noErr else {
            throw FFTAnalyzerError.CouldNotGetAudioFileFormat(err)
        }
        
        if sampleRate == 0 {
            sampleRate = fileASBD.mSampleRate
        }
        
        var clientASBD = AudioStreamBasicDescription()
        clientASBD.mSampleRate = fileASBD.mSampleRate
        clientASBD.mFormatID = kAudioFormatLinearPCM
        clientASBD.mFormatFlags = kAudioFormatFlagIsFloat
        clientASBD.mBytesPerPacket = 8
        clientASBD.mFramesPerPacket = 1
        clientASBD.mBytesPerFrame = 8
        clientASBD.mChannelsPerFrame = 2
        clientASBD.mBitsPerChannel = 32
        
        //set the ASBD to be used
        err = ExtAudioFileSetProperty(af, kExtAudioFileProperty_ClientDataFormat, size, &clientASBD)
        guard err == noErr else {
            throw FFTAnalyzerError.CouldNotSetAudioFormat(err)
        }
        
        //check the number of frames expected
        var numberOfFrames: Int64 = 0
        var propertySize = UInt32(sizeof(Int64))
        err = ExtAudioFileGetProperty(af, kExtAudioFileProperty_FileLengthFrames, &propertySize, &numberOfFrames)
        guard err == noErr else {
            throw FFTAnalyzerError.CouldNotGetAudioFileSize(err)
        }
        
        //initialize a buffer and a place to put the final data
        let bufferFrames = 4096
        let finalData = UnsafeMutablePointer<Float>.alloc(Int(numberOfFrames) * sizeof(Float.self))
        defer {
            finalData.dealloc(Int(numberOfFrames) * sizeof(Float.self))
        }
        
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
                throw FFTAnalyzerError.ErrorReadingAudioData(err)
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
        
        audioData = Array(UnsafeMutableBufferPointer(start: finalData, count: Int(count)))
        
        //dispose of the file
        err = ExtAudioFileDispose(af)
        guard err == noErr else {
            throw FFTAnalyzerError.GeneralError(err)
        }
        
        //fft operations
        let frames: Int
        if fftSamples == 0 {
            frames = Int(sampleRate)
        } else {
            frames = fftSamples
        }
        
        let fft_length = vDSP_Length(log2(CDouble(frames)))
        //let fft_length: UInt = 16
        let setup = vDSP_create_fftsetup(fft_length, Int32(kFFTRadix2))
        if setup == nil {
            fatalError("Could not setup fft")
        }
        
        let outReal = UnsafeMutablePointer<Float>.alloc(Int(frames/2) * sizeof(Float.self))
        defer {
            outReal.dealloc(Int(frames/2) * sizeof(Float.self))
        }
        let outImag = UnsafeMutablePointer<Float>.alloc(Int(frames/2) * sizeof(Float.self))
        defer {
            outImag.dealloc(Int(frames/2) * sizeof(Float.self))
        }
        
        var out = COMPLEX_SPLIT(realp: outReal, imagp: outImag)
        var dataAsComplex = UnsafePointer<COMPLEX>(finalData)
        
        vDSP_ctoz(dataAsComplex, 2, &out, 1, UInt(frames/2))
        vDSP_fft_zip(setup, &out, 1, fft_length, Int32(FFT_FORWARD))
        
        let power = UnsafeMutablePointer<Float>.alloc(Int(frames/2) * sizeof(Float.self))
        defer {
            power.dealloc(Int(frames/2) * sizeof(Float.self))
        }
        
        for i in 0..<frames/2 {
            power[i] = sqrt(outReal[i] * outReal[i] + outImag[i] * outImag[i])
            if isnan(power[i]) {
                throw FFTAnalyzerError.BadFFTDataProduced
            }
        }
        
        fftOutput = Array(UnsafeMutableBufferPointer(start: power, count: Int(frames/2)))
    
    }
}

let bsn = [#FileReference(fileReferenceLiteral: "bsn.mp3")#]
let url = [#FileReference(fileReferenceLiteral: "baah.wav")#]
let violinUrl = [#FileReference(fileReferenceLiteral: "violin.wav")#]
let donkey = [#FileReference(fileReferenceLiteral: "donkey.mp3")#]
let tone100hz = [#FileReference(fileReferenceLiteral: "100hz44100.wav")#]
let tone880hz = [#FileReference(fileReferenceLiteral: "880.wav")#]
let tone20000hz = [#FileReference(fileReferenceLiteral: "20000.wav")#]
let a = FFTAnalzer(url: tone100hz, sampleRate: 44100, fftSamples: 4096)
try! a.performAnalysis()
for x in a.fftOutput {
    x
}
