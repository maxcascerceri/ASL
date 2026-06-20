//
//  ASLApp.swift
//  ASL
//
//  Created by Max Cascerceri on 5/5/26.
//

import FirebaseCore
import FirebaseFirestore
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        let firestoreSettings = FirestoreSettings()
        firestoreSettings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = firestoreSettings
        PosterURLCache.configure()
        UILabel.appearance().textColor = Brand.textPrimaryUIColor
        UITextField.appearance().textColor = Brand.textPrimaryUIColor
        UITextView.appearance().textColor = Brand.textPrimaryUIColor
        _ = UIImage(named: "onboarding-splash")
        UnitMascot.preloadAllImages()
        return true
    }
}

@main
struct ASLApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
    }
}
