//
//  AKSettings.swift
//  AudioKit
//
//  Created by Stéphane Peter, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

import Foundation
import AVFoundation

/// Global settings for AudioKit
@objc open class AKSettings: NSObject {

    /// Enum of available buffer lengths
    /// from Shortest: 2 power 5 samples (32 samples = 0.7 ms @ 44100 kz)
    /// to Longest: 2 power 12 samples (4096 samples = 92.9 ms @ 44100 Hz)
    @objc public enum BufferLength: Int {

        /// Shortest
        case shortest = 5

        /// Very Short
        case veryShort = 6

        /// Short
        case short = 7

        /// Medium
        case medium = 8

        /// Long
        case long = 9

        /// Very Long
        case veryLong = 10

        /// Huge
        case huge = 11

        /// Longest
        case longest = 12

        /// The buffer Length expressed as number of samples
        public var samplesCount: AVAudioFrameCount {
            return AVAudioFrameCount(pow(2.0, Double(rawValue)))
        }

        /// The buffer Length expressed as a duration in seconds
        public var duration: Double {
            return Double(samplesCount) / AKSettings.sampleRate
        }
    }

    /// Constants for ramps used in AKParameterRamp.hpp, AKBooster, and others
    @objc public enum RampType: Int {
        case linear = 0
        case exponential = 1
        case logarithmic = 2
        case sCurve = 3
    }

    /// The sample rate in Hertz
    @objc open static var sampleRate: Double = 44_100

    /// Number of audio channels: 2 for stereo, 1 for mono
    @objc open static var channelCount: UInt32 = 2

    /// Whether we should be listening to audio input (microphone)
    @objc open static var audioInputEnabled: Bool = false

    /// Whether to allow audio playback to override the mute setting
    @objc open static var playbackWhileMuted: Bool = false

    /// Global audio format AudioKit will default to
    @objc open static var audioFormat: AVAudioFormat {
        return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)
    }

    /// Whether to output to the speaker (rather than receiver) when audio input is enabled
    @objc open static var defaultToSpeaker: Bool = false

    /// Whether to use bluetooth when audio input is enabled
    @objc open static var useBluetooth: Bool = false

    /// Additional control over the options to use for bluetooth
    @objc open static var bluetoothOptions: AVAudioSessionCategoryOptions = []

    /// Whether AirPlay is enabled when audio input is enabled
    @objc open static var allowAirPlay: Bool = false

    /// Global default rampDuration value
    @objc open static var rampDuration: Double = 0.000_2

    /// Allows AudioKit to send Notifications
    @objc open static var notificationsEnabled: Bool = false

    /// AudioKit buffer length is set using AKSettings.BufferLength
    /// default is .VeryLong for a buffer set to 2 power 10 = 1024 samples (232 ms)
    @objc open static var bufferLength: BufferLength = .veryLong

    /// The hardware ioBufferDuration. Setting this will request the new value, getting
    /// will query the hardware.
    @objc open static var ioBufferDuration: Double {
        set {
            do {
                try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(ioBufferDuration)

            } catch {
                AKLog(error)
            }
        }
        get {
            return AVAudioSession.sharedInstance().ioBufferDuration
        }
    }

    /// AudioKit recording buffer length is set using AKSettings.BufferLength
    /// default is .VeryLong for a buffer set to 2 power 10 = 1024 samples (232 ms)
    /// in Apple's doc : "The requested size of the incoming buffers. The implementation may choose another size."
    /// So setting this value may have no effect (depending on the hardware device ?)
    @objc open static var recordingBufferLength: BufferLength = .veryLong

    /// If set to true, Recording will stop after some delay to compensate
    /// latency between time recording is stopped and time it is written to file
    /// If set to false (the default value) , stopping record will be immediate,
    /// even if the last audio frames haven't been recorded to file yet.
    @objc open static var fixTruncatedRecordings = false

    /// Enable AudioKit AVAudioSession Category Management
    @objc open static var disableAVAudioSessionCategoryManagement: Bool = false

    /// If set to false, AudioKit will not handle the AVAudioSession route change
    /// notification (AVAudioSessionRouteChange) and will not restart the AVAudioEngine
    /// instance when such notifications are posted. The developer can instead subscribe
    /// to these notifications and restart AudioKit after rebuiling their audio chain.
    @objc open static var enableRouteChangeHandling: Bool = true

    /// If set to false, AudioKit will not handle the AVAudioSession category change
    /// notification (AVAudioEngineConfigurationChange) and will not restart the AVAudioEngine
    /// instance when such notifications are posted. The developer can instead subscribe
    /// to these notifications and restart AudioKit after rebuiling their audio chain.
    @objc open static var enableCategoryChangeHandling: Bool = true

    /// Turn off AudioKit logging
    @objc open static var enableLogging: Bool = true

    /// Checks the application's info.plist to see if UIBackgroundModes includes "audio".
    /// If background audio is supported then the system will allow the AVAudioEngine to start even if the app is in,
    /// or entering, a background state. This can help prevent a potential crash
    /// (AVAudioSessionErrorCodeCannotStartPlaying aka error code 561015905) when a route/category change causes
    /// AudioEngine to attempt to start while the app is not active and background audio is not supported.
    @objc open static let appSupportsBackgroundAudio = (Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String])?.contains("audio") ?? false
}

extension AKSettings {

    /// Shortcut for AVAudioSession.sharedInstance()
    @objc open static let session = AVAudioSession.sharedInstance()

    /// Convenience method accessible from Objective-C
    @objc open static func setSession(category: SessionCategory, options: UInt) throws {
        try setSession(category: category, with: AVAudioSessionCategoryOptions(rawValue: options))
    }

    /// Set the audio session type
    @objc open static func setSession(category: SessionCategory,
                                      with options: AVAudioSessionCategoryOptions = [.mixWithOthers]) throws {

        if ❗️AKSettings.disableAVAudioSessionCategoryManagement {
            do {
                try session.setCategory("\(category)", with: options)
            } catch let error as NSError {
                AKLog("Error: \(error) Cannot set AVAudioSession Category to \(category) with options: \(options)")
                throw error
            }
        }

        // Preferred IO Buffer Duration
        do {
            try session.setPreferredIOBufferDuration(bufferLength.duration)
        } catch let error as NSError {
            AKLog("AKSettings Error: Cannot set Preferred IOBufferDuration to " +
                "\(bufferLength.duration) ( = \(bufferLength.samplesCount) samples)")
            AKLog("AKSettings Error: \(error))")
            throw error
        }

        // Activate session
        do {
            try session.setActive(true)
        } catch let error as NSError {
            AKLog("AKSettings Error: Cannot set AVAudioSession.setActive to true", error)
            throw error
        }
    }

    @objc open static func computedSessionCategory() -> SessionCategory {
        if AKSettings.audioInputEnabled {
            return .playAndRecord
        } else if AKSettings.playbackWhileMuted {
            return .playback
        } else {
            return .ambient
        }
    }

    @objc open static func computedSessionOptions() -> AVAudioSessionCategoryOptions {

        var options: AVAudioSessionCategoryOptions = [.mixWithOthers]

        if AKSettings.audioInputEnabled {

            options = options.union(.mixWithOthers)

            // Default to Speaker
            if AKSettings.defaultToSpeaker {
                options = options.union(.defaultToSpeaker)
            }
            #endif
        }

        return options
    }

    /// Enum of available AVAudioSession Categories
    @objc public enum SessionCategory: Int, CustomStringConvertible {
        /// Audio silenced by silent switch and screen lock - audio is mixable
        case ambient
        /// Audio is silenced by silent switch and screen lock - audio is non mixable
        case soloAmbient
        /// Audio is not silenced by silent switch and screen lock - audio is non mixable
        case playback
        /// Silences playback audio
        case record
        /// Audio is not silenced by silent switch and screen lock - audio is non mixable.
        /// To allow mixing see AVAudioSessionCategoryOptionMixWithOthers.
        case playAndRecord
        /// Disables playback and recording; deprecated in iOS 10
        case audioProcessing
        /// Use to multi-route audio. May be used on input, output, or both.
        case multiRoute

        public var description: String {
            switch self {
            case .ambient:
                return AVAudioSessionCategoryAmbient
            case .soloAmbient:
                return AVAudioSessionCategorySoloAmbient
            case .playback:
                return AVAudioSessionCategoryPlayback
            case .record:
                return AVAudioSessionCategoryRecord
            case .playAndRecord:
                return AVAudioSessionCategoryPlayAndRecord
            case .multiRoute:
                return AVAudioSessionCategoryMultiRoute
            case .audioProcessing:
                #if !os(tvOS)
                return AVAudioSessionCategoryAudioProcessing
                #else
                return "AVAudioSessionCategoryAudioProcessing"
                #endif
            }
        }
    }
}
