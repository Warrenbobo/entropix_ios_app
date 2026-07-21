#!/bin/bash
# Installs CocoaPods (user gem) if missing, then runs pod install.
set -euo pipefail

GEM_BIN="$HOME/.gem/ruby/2.6.0/bin"
export PATH="$GEM_BIN:$PATH"

if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods not found — installing to user gem directory..."
  gem install ffi -v 1.15.5 --user-install
  gem install securerandom -v 0.3.2 --user-install
  gem install i18n -v 1.14.8 --user-install
  gem install cocoapods -v 1.13.0 --user-install
  export PATH="$GEM_BIN:$PATH"
fi

echo "Using CocoaPods $(pod --version)"
pod install

echo ""
echo "Done. Open processor.xcworkspace (not .xcodeproj) in Xcode."
