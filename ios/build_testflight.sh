#!/bin/bash
#
# QuickTranslate TestFlight ビルド＆アップロードスクリプト
#
# 前提条件:
#   1. Apple Developer Programに加入済み
#   2. Xcodeでチームアカウントにサインイン済み
#   3. App Store ConnectでApp登録済み（Bundle ID: com.quicktranslate.ios）
#
# 使い方:
#   cd QuickTranslate/ios
#   ./build_testflight.sh
#

set -euo pipefail

# --- 設定 ---
SCHEME="QuickTranslate"
PROJECT="QuickTranslate.xcodeproj"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/QuickTranslate.xcarchive"
EXPORT_PATH="./build/export"
EXPORT_OPTIONS="ExportOptions.plist"

# --- カラー出力 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 事前チェック ---
info "事前チェック中..."

if [ ! -f "$PROJECT/project.pbxproj" ]; then
    error "Xcodeプロジェクトが見つかりません。ios/ ディレクトリで実行してください。"
fi

if [ ! -f "$EXPORT_OPTIONS" ]; then
    error "ExportOptions.plist が見つかりません。"
fi

if ! command -v xcodebuild &> /dev/null; then
    error "xcodebuild が見つかりません。Xcodeをインストールしてください。"
fi

# Xcodeのパスを確認（Command Line Toolsではなく、Xcode.appが必要）
XCODE_PATH=$(xcode-select -p 2>/dev/null)
if [[ "$XCODE_PATH" == */CommandLineTools* ]]; then
    warn "xcode-select が Command Line Tools を指しています。Xcode.appに切り替えます..."
    warn "sudo が必要です:"
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi

# Xcodeのバージョン表示
info "Xcode version: $(xcodebuild -version | head -1)"

# --- クリーンアップ ---
info "ビルドディレクトリをクリーンアップ中..."
rm -rf ./build

# --- アーカイブ ---
info "アーカイブ作成中... (数分かかる場合があります)"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic

if [ ! -d "$ARCHIVE_PATH" ]; then
    error "アーカイブの作成に失敗しました。"
fi
info "アーカイブ作成完了: $ARCHIVE_PATH"

# --- エクスポート＆アップロード ---
info "App Store Connectにアップロード中..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates

info "========================================="
info "  アップロード完了!"
info "========================================="
info ""
info "次のステップ:"
info "  1. App Store Connect (https://appstoreconnect.apple.com) を開く"
info "  2. QuickTranslate → TestFlight タブを確認"
info "  3. ビルドの処理完了を待つ (5〜30分)"
info "  4. 「外部テスター」グループを作成しテスターを招待"
info ""
