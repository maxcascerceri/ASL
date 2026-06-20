//
//  LessonSounds.swift
//  ASL
//
//  Audio plumbing for the dopamine loop. Ships silent in the MVP: each cue
//  looks for a `.caf` file in the app bundle and plays it if present. Drop
//  files like `tap.caf`, `correct.caf`, etc. into the bundle later and the
//  whole soundscape lights up with zero code change.
//

import AVFoundation

enum LessonSound: String, CaseIterable {
    case tap = "tap"
    case correct = "correct"
    case wrong = "wrong"
    case stoneComplete = "stoneComplete"
    case unitComplete = "unitComplete"
}

enum LessonSounds {
    private static let players: [LessonSound: AVAudioPlayer] = LessonSound.allCases.reduce(into: [:]) { acc, cue in
        if let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "caf"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            acc[cue] = player
        }
    }

    /// Best-effort playback. If no audio file ships for this cue we silently
    /// no-op so the lesson loop keeps the same rhythm with sound off.
    static func play(_ cue: LessonSound) {
        guard ASLSettings.lessonSoundsEnabled else { return }
        guard let player = players[cue] else { return }
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.play()
    }
}
