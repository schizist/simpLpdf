# SPEC

## Goal

Create a minimal iPad PDF tool optimized for:

* fast page extraction
* simple UX
* custom gesture control

## Platform

* iPadOS only
* Swift + SwiftUI
* PDFKit for document handling

## MVP Features

### 1. Import

* Load PDF from Files picker

### 2. Viewer

* Display PDF pages
* Scroll vertically

### 3. Page Selection

* Show thumbnails
* Allow multi-select

### 4. Export

* Export selected pages:

  * as one combined PDF
  * as separate PDFs

### 5. Gestures

* Two-finger tap = undo
* Three-finger tap = redo

## Constraints

* No third-party libraries
* Keep architecture simple
* No over-engineering

## Definition of Done

* Opens a PDF
* Selects at least one page
* Exports that page as a new PDF
* Builds cleanly in Xcode
