# 🕹️ GamesHub (iOS)

> 100種類のミニゲームを、ひとつの SwiftUI アプリに。

GamesHub は SwiftUI で実装した、100種類のミニゲームを収録したオールインワン・ゲームコレクション（iOS版）です。各ゲームはデザインを磨き込んだ複数バージョン（V2 / V3）で実装され、ハブ画面から好きなゲームをすぐに起動できます。

![Platform](https://img.shields.io/badge/Platform-iOS%2017+-000000?style=flat-square&logo=apple) ![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat-square&logo=swift&logoColor=white) ![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?style=flat-square&logo=swift&logoColor=white) ![XcodeGen](https://img.shields.io/badge/XcodeGen-project.yml-2196F3?style=flat-square) ![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

---

## 📸 スクリーンショット

| ハブ画面 | 2048 | Match3 |
|---|---|---|
| ![hub](screenshots/final_hub.png) | ![2048](screenshots/2048_v3.png) | ![match3](screenshots/match3_v3.png) |

| Wordle | Memory | Tower Defense |
|---|---|---|
| ![wordle](screenshots/wordle_v3.png) | ![memory](screenshots/memory_v3_final.png) | ![td](screenshots/towerdefense_v3.png) |

---

## ✨ 特徴

- **100 ミニゲーム** — Sudoku / Match3 / WordSearch / 2048 / Solitaire / Tetris など幅広いジャンルを収録
- **磨き込みの V2 / V3 実装** — 主要ゲームはデザイン・操作性を改善した複数バージョンを用意
- **純 SwiftUI** — 外部ゲームエンジン非依存、すべてネイティブ実装
- **ハブ型ナビゲーション** — 1画面から全ゲームへアクセス
- **XcodeGen 管理** — `project.yml` からプロジェクトを再現可能に生成

---

## 🛠️ 技術スタック

| カテゴリ | 技術 |
|---|---|
| 言語 | Swift 5.9 |
| UI | SwiftUI |
| プロジェクト生成 | XcodeGen (`project.yml`) |
| 対応OS | iOS 17.0+ |
| Bundle ID | `com.gameshub.GamesHub` |

---

## 🚀 セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/masafykun/GamesHub.git
cd GamesHub

# XcodeGen でプロジェクトを生成（未インストールなら: brew install xcodegen）
xcodegen generate

# Xcode で開いてビルド・実行
open GamesHub.xcodeproj
```

---

## ライセンス

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

このプロジェクトは **MIT ライセンス** のもとで公開しています。

© 2026 masafykun (https://github.com/masafykun)
