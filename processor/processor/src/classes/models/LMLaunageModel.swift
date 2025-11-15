//
//  LMLaunageModel.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import Foundation

// MARK: - Language Model
struct LMLaunageModel: Codable {
    var english: LMAppLaunageConfig?
    var chinese: LMAppLaunageConfig?
}

// MARK: - App Language Config
struct LMAppLaunageConfig: Codable {
    var common: LMCommonTextConfig?
    var camera: LMCameraTextConfig?
    var profile: LMProfileTextConfig?
    var subscription: LMSubscriptionTextConfig?
    var auth: LMAuthTextConfig?
    var settings: LMSettingsTextConfig?
}

// MARK: - Common Text Config
struct LMCommonTextConfig: Codable {
    var ok: String = "OK"
    var cancel: String = "Cancel"
    var save: String = "Save"
    var back: String = "Back"
    var done: String = "Done"
    var edit: String = "Edit"
    var delete: String = "Delete"
    var confirm: String = "Confirm"
    var loading: String = "Loading..."
    var error: String = "Error"
    var success: String = "Success"
    var retry: String = "Retry"
    var close: String = "Close"
}

// MARK: - Camera Text Config
struct LMCameraTextConfig: Codable {
    // Camera Controls
    var flash: String = "Flash"
    var ratio: String = "Ratio"
    var timer: String = "Timer"
    var live: String = "Live"
    var grid: String = "Grid"
    var flipCamera: String = "Flip Camera"
    var arGuidance: String = "AR Guidance"
    
    // Inspire Button
    var inspireMeButton: String = "Inspire Me  ⓘ"
    var inspirePointsFormat: String = "Inspire Point -%d"
    
    // Guidance Messages
    var guidanceNotice: String = "Please get inspiration before use of AI guidance"
    var alignPersonFrame: String = "Align the person with the green frame"
    var generating: String = "Generating..."
    var generatingAISuggestions: String = "Generating AI suggestions..."
    var analyzingScene: String = "Analyzing scene..."
    var allSuggestionsReady: String = "All suggestions ready!"
    var generationFailed: String = "Generation failed. Please try again."
    var generationTimeout: String = "Generation timeout. Showing available suggestions."
    
    // Composition
    var compositionSuggestions: String = "Composition Suggestions"
}

// MARK: - Profile Text Config
struct LMProfileTextConfig: Codable {
    // Page Titles
    var profile: String = "Profile"
    var accountProfile: String = "Account Profile"
    var gallery: String = "Gallery"
    var savedIdeas: String = "Saved Ideas"
    
    // Membership Card
    var plusPlan: String = "Plus Plan"
    var freePlan: String = "Free Plan"
    var unlimitedInspires: String = "Unlimited Inspires"
    var limitedUsage: String = "Limited Usage"
    var unlimited: String = "Unlimited"
    var inspirePoints: String = "Inspire Points"
    var watchAds: String = "Watch Ads"
    var watchAdsWithIcon: String = "▶ Watch Ads"
    var upgrade: String = "Upgrade"
    var plusIndicator: String = "+5"
    
    // Profile Display
    var fullName: String = "Full Name"
    var username: String = "Username"
    var emailAddress: String = "Email Address"
    var dateOfBirth: String = "Date of Birth"
    var subscriptionType: String = "Subscription Type"
    var cancelSubscription: String = "Cancel Subscription"
    var editProfileData: String = "Edit Profile Data"
    
    // Profile Edit
    var changePhoto: String = "Change Photo"
    var changePassword: String = "Change Password"
    var camera: String = "Camera"
    var photoLibrary: String = "Photo Library"
    
    // Alerts
    var profileUpdated: String = "Profile Updated"
    var profileUpdatedMessage: String = "Your profile has been updated successfully."
    var cancelSubscriptionTitle: String = "Cancel Subscription"
    var cancelSubscriptionMessage: String = "Are you sure you want to cancel your subscription? You will lose access to premium features."
    var keepSubscription: String = "Keep Subscription"
    var subscriptionCancelled: String = "Subscription Cancelled"
    var subscriptionCancelledMessage: String = "Your subscription has been cancelled successfully."
}

// MARK: - Subscription Text Config
struct LMSubscriptionTextConfig: Codable {
    // Page Title
    var subscriptionTitle: String = "Subscription"
    
    // Countdown
    var limitedTimeOffer: String = "Limited Time Offer Ends In:"
    var days: String = "Days"
    var day: String = "Day"
    var hours: String = "Hours"
    var hour: String = "Hour"
    var minutes: String = "Minutes"
    var minute: String = "Minute"
    var seconds: String = "Seconds"
    var second: String = "Second"
    
    // Progress
    var limitedSpotsAvailable: String = "Limited Spots Available:"
    var spotsLeftFormat: String = "Only %d spots left!"
    
    // Plan Details
    var unlimitedAISuggestions: String = "Get unlimited AI suggestions, advanced features, and priority support"
    var autoRenewsMonthly: String = "Auto-renews monthly, cancel anytime"
    var freeInspirePoints: String = "3 free Inspire points for new downloads"
    
    // Features
    var unlimitedInspirePoints: String = "Unlimited Inspire Points"
    var aiInspiring: String = "AI Inspiring"
    var basicCamera: String = "Basic Camera"
    var advancedCamera: String = "Advanced Camera"
    var prioritySupport: String = "Priority Support"
    var noAds: String = "No Ads"
    
    // Buttons
    var startFreeTrial: String = "Start Free Trial"
    var subscribe: String = "Subscribe"
    var continueWithFree: String = "Continue with Free"
    var giveUpFreeTrial: String = "Give up Free Trial?"
    var giveUp: String = "Give up"
    var kContinue: String = "Continue"
    var watchAd: String = "Watch Ad"
    var watchAdsToGetFree: String = "Watch ads to get 5 free AI suggestions"
    var selectAndContinue: String = "Select & Continue"
    var regenerate: String = "Regenerate"
    var oneTimePayment: String = "One-time payment, yours forever"
    
    // Footer
    var autoRenewNotice: String = "Auto-renewing subscriptions automatically renew unless canceled at least 24 hours before the end of the current period."
    var termsOfService: String = "Terms of Service"
    var privacyPolicy: String = "Privacy Policy"
}

// MARK: - Auth Text Config
struct LMAuthTextConfig: Codable {
    // Sign In
    var signIn: String = "Sign In"
    var email: String = "Email"
    var password: String = "Password"
    var forgotPassword: String = "Forgot password?"
    var dontHaveAccount: String = "Don't have an account?"
    var signUp: String = "Sign Up"
    
    // Sign Up
    var createAccount: String = "Create Account"
    var fullName: String = "Full Name"
    var confirmPassword: String = "Confirm Password"
    var alreadyHaveAccount: String = "Already have an account?"
    
    // Forgot Password
    var resetPassword: String = "Reset Password"
    var sendResetLink: String = "Send Reset Link"
    var backToSignIn: String = "Back to Sign In"
    
    // Email Verification
    var emailVerification: String = "Email Verification"
    var verifyYourEmail: String = "Verify Your Email"
    var verificationCodeSent: String = "We've sent a verification code to"
    var resendCode: String = "Resend Code"
    var verify: String = "Verify"
    var verificationCodeResent: String = "Verification code has been resent"
    var emailVerified: String = "Email verified successfully"
    
    // Validation
    var emailRequired: String = "Email is required"
    var passwordRequired: String = "Password is required"
    var passwordMismatch: String = "Passwords do not match"
    var invalidEmail: String = "Invalid email format"
    
    // Messages
    var signInSuccess: String = "Sign in successful"
    var signUpSuccess: String = "Account created successfully"
    var resetLinkSent: String = "Reset link sent to your email"
    var availableWithoutAccount: String = "Available Without Account"
    
    // Session
    var sessionExpired: String = "Session Expired"
    var pleaseSignInAgain: String = "Your session has expired, please sign in again"
    
    // Additional
    var createAccountTitle: String = "Create Account"
    var createAccountSubtitle: String = "Join us to discover your creativity"
    var appName: String = "InspireCam"
    var appTagline: String = "Unlock your creative potential"
    var or: String = "or"
    var passwordRequirement: String = "Password must be at least 8 characters with\nat least one number and one letter."
    var changing: String = "Changing..."
    var loggingOut: String = "Logging Out..."
    var logOut: String = "Log Out"
}

// MARK: - Settings Text Config
struct LMSettingsTextConfig: Codable {
    // Settings Page
    var settings: String = "Settings"
    var account: String = "Account"
    var general: String = "General"
    var about: String = "About"
    
    // Account Section
    var accountProfile: String = "Account Profile"
    var changePassword: String = "Change Password"
    var signOut: String = "Sign Out"
    var deleteAccount: String = "Delete Account"
    
    // General Section
    var language: String = "Language"
    var notifications: String = "Notifications"
    var cameraSettings: String = "Camera Settings"
    var dataAndStorage: String = "Data & Storage"
    
    // About Section
    var appVersion: String = "App Version"
    var termsOfService: String = "Terms of Service"
    var privacyPolicy: String = "Privacy Policy"
    var contactUs: String = "Contact Us"
    var rateApp: String = "Rate App"
    var shareApp: String = "Share App"
    
    // Support
    var helpAndSupport: String = "Help & Support"
    var faq: String = "Common Questions & Answers"
    var contactSupport: String = "Contact our support team for personalized help."
    var getInTouch: String = "Get in Touch"
    var connectCommunity: String = "Connect with our community"
    var framAIstTeam: String = "FramAIst Team"
    var appDeveloper: String = "App Developer"
    
    // Earn Free Uses
    var earnFreeUses: String = "Earn Free Uses"
    var downloaded: String = "Downloaded"
    var selectLanguage: String = "Select Language"
    var view: String = "View"
    var back: String = " Back"
    var goShot: String = "Go Shot"
    var deleting: String = "Deleting..."
    var copied: String = "Copied!"
    var joinDiscord: String = "Join Our Discord Channel"
    var inviteLink: String = "Invite Link:"
    var sendMessage: String = "Send us a message directly"
    var needHelp: String = "Need Help?"
    var respondWithin24Hours: String = "We typically respond within 24 hours."
    var stillHaveQuestions: String = "Still have questions?"
    var accountProfileSubtitle: String = "Manage your account settings"
    var notificationSubtitle: String = "Receive system notifications from us"
    var languageSubtitle: String = "Change In-App Language"
    var contactUsSubtitle: String = "Get help and support"
    var frequentQuestionsSubtitle: String = "Find answers to common questions"
    var aboutSubtitle: String = "App information and support"
    var frequentQuestions: String = "Frequent Questions"
    var comingSoon: String = "Coming Soon"
    var comingSoonMessage: String = "%@ will be available in a future update."
    var areYouSureLogout: String = "Are you sure you want to log out?"
    var unlockCreativePotential: String = "Unlock Your Creative Potential"
    var giveUpFreeTrialMessage: String = "When you switch to free plan, you give up this free trial opportunity. You will not be able to get free trial again until a new offer is provided."
    var welcomeToApp: String = "Welcome to InspireCam"
    var signInToDiscover: String = "Sign in to discover full features"
    var takePhotosStandard: String = "Take photos with standard features"
    var leftFormat: String = "%d left"
    var languageChangedSuccess: String = "Language changed successfully. All text will be updated."
    var switchToFormat: String = "Switch to %@?"
    
    // Welcome Authentication
    var signInWithEmail: String = "Sign in with Email"
    var termsAndPrivacy: String = "By continuing, you agree to our Terms of Service and Privacy Policy"
    var termsOfServiceLink: String = "Terms of Service"
    var privacyPolicyLink: String = "Privacy Policy"
    var noAccountPrompt: String = "Don't have an account? Sign up"
    var signUpLink: String = "Sign up"
}
