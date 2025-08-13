# Shelfie Development Instructions

## 🎯 Primary Reference
**ALWAYS consult `prd.md` before performing any development task.** This file contains the complete product specification, architecture, and requirements for the Shelfie read/watch later system.

## 🏗️ Project Architecture
This is a cross-platform "read & watch later" system consisting of:
- Flutter app (Windows desktop + Android)
- Chrome/Edge browser extension
- Supabase backend (Postgres + Edge Functions)

Always consider the full architecture when making changes to ensure compatibility across all components.