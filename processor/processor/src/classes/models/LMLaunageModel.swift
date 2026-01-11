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
    var entrance: LMEntranceTextConfig?
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
    var kindTips: String = "Kind Tips"
    var openSettings: String = "Open Settings"
    var leave: String = "Leave"
    var saving: String = "Saving..."
    var networkError: String = "Network error, please try again"
    var pleaseSignIn: String = "Please sign in"
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
    var inspireMeButton: String = "Inspire Me"
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
    
    // Inspire Me Messages
    var inspireMeOnlyBackCamera: String = "Inspire Me is only available with back camera"
    var cameraNotReady: String = "Camera is not ready. Please try again."
    var outOfInspirePoints: String = "Out of Inspire Points"
    var subscribeOrWatchAds: String = "Please subscribe or earn points by watching ads."
    
    // Camera Access
    var cameraAccessDenied: String = "Camera Access Denied"
    var cameraAccessRequired: String = "Camera access is required to use this feature."
    var cameraAccessRequiredTitle: String = "Camera Access Required"
    var cameraAccessRequiredMessage: String = "FramAist needs camera access to take photos. Please enable camera access in Settings."
    
    // Give Up Inspires
    var giveUpInspires: String = "Give Up Inspires?"
    var giveUpInspiresMessage: String = "You will return to the camera. This action cannot be undone."
    
    // Photo Save
    var photoSavedToGallery: String = "Photo saved to Gallery"
    var failedToSavePhoto: String = "Failed to save photo. Please try again."
    var photoLibraryAccessRequired: String = "Photo Library Access Required"
    var photoLibraryAccessRequiredMessage: String = "FramAist needs photo library access to save photos. Please enable photo library access in Settings."
    var failedToSaveLivePhoto: String = "Failed to save Live Photo"
    var livePhotoVideoNotFound: String = "Live Photo video file not found"
    var savedToAlbum: String = "Saved to Album"
    var livePhotoDataNotFound: String = "Live Photo data not found"
    var livePhotoImageNotFound: String = "Live Photo image not found"
    var failedToCapturePhoto: String = "Failed to capture photo"
    var failedToProcessCapturedPhoto: String = "Failed to process captured photo"
    var livePhotosNotSupported: String = "Live Photos is not supported on this device."
    var livePhotos: String = "Live Photos"
    var selectCompositionFirst: String = "Please select a composition with loaded image first"
    var failedToCaptureFrame: String = "Failed to capture frame from video stream"
    var failedToProcessFrame: String = "Failed to process captured frame"
    var inspireMeHint: String = "Tap to get AI-powered composition suggestions for your photo. Each use costs 1 Inspire Point."
    var inspireMeFrontCameraHint: String = "Inspire Me not available on front camera. Please switch to back camera to use this feature."
    var suggestionSavedToFavorites: String = "Suggestion saved to favorites"
    var noMoreSuggestionsAvailable: String = "No more suggestions available"
    var pleaseWaitForImageToLoad: String = "Please wait for image to load"
    var imageCompressionFailed: String = "Image compression failed"
    var imageOptimizationFailed: String = "Image optimization failed"
    var analysisFailed: String = "Analysis failed"
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
    var getFreeTrial: String = "Get Free Trial"
    var freeTrialClaimed: String = "Free Trial Claimed"
    var claimingFreeTrial: String = "Claiming..."
    var tilExpiration: String = "Til Expiration"
    var daysFormat: String = "%d Days"
    var dayFormat: String = "%d Day"
    
    // Profile Display
    var fullName: String = "Full Name"
    var username: String = "Username"
    var emailAddress: String = "Email Address"
    var dateOfBirth: String = "Date of Birth"
    var dateOfBirthOptional: String = "Date of Birth (optional)"
    var subscriptionType: String = "Subscription Type"
    var avatar: String = "Avatar"
    var nickname: String = "Nickname"
    var enterNickname: String = "Enter your nickname"
    var enterUsername: String = "Enter your username"
    var dateFormatPlaceholder: String = "YYYY/MM/DD"
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
    
    // Edit Profile
    var discardChanges: String = "Discard Changes?"
    var discardChangesMessage: String = "Exiting edit mode will discard all unsaved changes. Are you sure you want to exit?"
    var discard: String = "Discard"
    var failedToSaveProfile: String = "Failed to save profile"
    var avatarUpdated: String = "Avatar updated"
    var failedToProcessImage: String = "Failed to process the selected image. Please try again."
    var choosePhotoSource: String = "Choose a photo source"
    var subscriptionDetails: String = "Subscription details"
    var uploadingAvatar: String = "Uploading avatar..."
    
    // Gallery & Saved Ideas
    var deletePhotoConfirm: String = "Are you sure to delete this photo from gallery?"
    var actionCannotBeUndone: String = "This action cannot be undone."
    var removeSavedIdeaConfirm: String = "Remove this photo from Saved Idea?"
    var actionCannotBeRecall: String = "This action cannot be recall."
    var failedToRemoveSavedIdea: String = "Failed to remove saved idea. Please try again."
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
    
    // Trial Expired
    var trialExpiredTitle: String = "Trial Expired"
    var trialExpiredMessage: String = "Your trial membership has expired. Subscribe to continue using."
    var subscribeNow: String = "Subscribe Now"
    var gotIt: String = "Got It"
    
    // Purchase
    var chooseYourPlan: String = "Choose Your Plan"
    var processingPurchase: String = "Processing purchase..."
    var purchaseSuccessFormat: String = "🎉 Successfully subscribed to %@!"
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
    
    // Sign In/Up Process
    var signingIn: String = "Signing in..."
    var creatingAccount: String = "Creating Account..."
    var resetting: String = "Resetting..."
    var passwordResetSuccess: String = "Password reset successfully! Please sign in."
    var enterEmailAndNewPassword: String = "Enter your email and new password to reset your password."
    var emailAddress: String = "Email address"
    var newPassword: String = "New password"
    var confirmNewPassword: String = "Confirm new password"
    var usernameEmailOrMobile: String = "Username, email or mobile number"
    var login: String = "Login"
    var invalidCredentials: String = "Invalid credentials. Please check your username and password."
    var agreeToTermsRequired: String = "Please agree to the terms and conditions to continue."
    var accountCreatedVerifyEmail: String = "Account created! Please check your email to verify."
    var pleaseConfirmPassword: String = "Please confirm your password"
    var passwordsDoNotMatch: String = "Passwords do not match"
    var usernameRequired: String = "Username is required"
    var usernameMinLength: String = "Username is required (minimum 3 characters)"
    var pleaseEnterValidEmail: String = "Please enter a valid email address"
    var passwordMinLength: String = "Password must be at least 8 characters"
    var passwordRequirementFull: String = "Password must be at least 8 characters with at least one number and one letter"
    var passwordMustContainLetter: String = "Password must contain at least one letter"
    var passwordMustContainNumber: String = "Password must contain at least one number"
    var enterYourEmail: String = "Enter your email"
    var enterYourPassword: String = "Enter your password"
    var confirmYourPassword: String = "Confirm your password"
    var termsAndConditions: String = "terms and conditions"
    var termsAndConditionsTitle: String = "Terms and Conditions"
    var termsAgreementText: String = "By agreeing to the terms and conditions, you are entering into a legally binding contract with the service provider."
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
    var framAIstTeam: String = "Entropix Ltd. FramAIst Team"
    var appDeveloper: String = "App Developer"
    
    // Earn Free Uses
    var earnFreeUses: String = "Earn Free Uses"
    var downloaded: String = "Downloaded"
    var selectLanguage: String = "Select Language"
    var view: String = "View"
    var back: String = " Back"
    var goShot: String = "Go Shot"
    var deleting: String = "Deleting..."
    var joinDiscord: String = "Join Our Discord Channel"
    var inviteLink: String = "Invite Link:"
    var sendMessage: String = "Send us a message directly"
    var needHelp: String = "Need Help?"
    var respondWithin24Hours: String = "We typically respond within 24 hours."
    var stillHaveQuestions: String = "Still have questions?"
    var unableToOpen: String = "Unable to Open"
    var copyInviteLinkMessage: String = "Please copy the invite link and open it in your browser."
    var copyEmailMessage: String = "Please copy the email address and use your preferred email client."
    var discordInviteLinkCopied: String = "Discord invite link copied!"
    var emailAddressCopied: String = "Email address copied!"
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
    
    // Debug
    var debugTest: String = "Debug Test"
    var debugTestSubtitle: String = "View API logs and export user data"
    
    // Permission
    var featureAccessRequiredFormat: String = "%@ Access Required"
    var enableFeatureAccessMessage: String = "Please enable %@ access in Settings to change your profile photo."
    
    // Debug Test Page
    var requestLogs: String = "Request Logs"
    var requestDetails: String = "Request Details"
    var clear: String = "Clear"
    var noRequestLogs: String = "No request logs"
    var confirmClear: String = "Confirm Clear"
    var confirmClearMessage: String = "Are you sure you want to clear all request logs?"
    var overview: String = "Overview"
    var request: String = "Request"
    var response: String = "Response"
    var copy: String = "Copy"
    var copied: String = "Copied"
    var basicInfo: String = "Basic Info"
    var url: String = "URL"
    var method: String = "Method"
    var statusCode: String = "Status Code"
    var duration: String = "Duration"
    var requestTime: String = "Request Time"
    var isSuccess: String = "Is Success"
    var yes: String = "Yes"
    var no: String = "No"
    var requestHeaders: String = "Request Headers"
    var cookies: String = "Cookies"
    var requestBody: String = "Request Body"
    var responseHeaders: String = "Response Headers"
    var responseBody: String = "Response Body"
    var none: String = "(None)"
    var noData: String = "(No data)"
}

// MARK: - Entrance Text Config
struct LMEntranceTextConfig: Codable {
    var entropix: String = "Entropix"
    var unleashCreativity: String = "Unleash Your Creativity in Photography"
    var noNetworkConnection: String = "No network connection detected. Please check your network settings and restart the app."
    var privacyPermission: String = "Privacy Permission"
    var privacyDescription: String = "We collect and use your data to provide personalized services, improve app functionality, and enhance your experience. Your data is securely stored and will not be shared with third parties without your consent."
    var agree: String = "Agree"
    var rejectAndExit: String = "Reject and Exit"
    var viewPrivacyAndTerms: String = "View our Privacy Policy and Terms of Service"
}
