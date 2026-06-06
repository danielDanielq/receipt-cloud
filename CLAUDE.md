# Receipt Cloud — Project Context

## What this app does
A Flutter mobile app that scans fiscal receipts using the phone camera,
extracts data via Google Cloud Vision API (OCR), and saves parsed 
receipt data to Firebase Firestore.

## Tech Stack
- Flutter 3.44.1 / Dart 3.12.1
- Firebase (Firestore for database, Authentication for users)
- Google Cloud Vision API for OCR
- Target platforms: Android (primary), Windows (development/testing)

## Project Structure
- lib/main.dart — entry point
- lib/screens/ — UI screens
- lib/services/ — Firebase and Vision API logic
- lib/models/ — data models

## Rules
- Never delete files without confirming with me first
- After each feature is complete, explain what was built and what's next
- If something is unclear, ask before implementing
- Use Provider for state management
- All async functions must have proper error handling with try/catch
- Keep UI and business logic separated

## Current Status
Fresh Flutter project created. Firebase project: receipt-cloud-16d79.
No code written yet beyond Flutter default template.

## Core Data Model
A Receipt has: vendor (String), date (DateTime), total (double),
items (List of String), imageUrl (String), userId (String),
createdAt (DateTime)
