//
//  ViewStateModels.swift
//  Curtain
//
//  Created by Claude on 07/01/2026.
//  State management models for organizing view state into focused, testable groups
//

import Foundation
import CoreGraphics

// MARK: - Plot Loading View State

/// Manages plot loading, error states, and selected points
struct PlotLoadingViewState {
    var isLoading: Bool = true
    var error: String? = nil
    var selectedPoints: [ProteinPoint] = []

    // MARK: - Computed Properties

    /// Returns true if there's an error message
    var hasError: Bool { error != nil }

    /// Returns true if the plot is ready (not loading and no error)
    var isReady: Bool { !isLoading && error == nil }

    // MARK: - State Transitions

    /// Set the view to loading state, clearing any errors
    mutating func setLoading() {
        isLoading = true
        error = nil
    }

    /// Set an error state with a message
    mutating func setError(_ message: String) {
        isLoading = false
        error = message
    }

    /// Set the view to ready state (loaded successfully)
    mutating func setReady() {
        isLoading = false
        error = nil
    }

    /// Clear selected points
    mutating func clearSelection() {
        selectedPoints = []
    }

    /// Update selected points
    mutating func updateSelection(_ points: [ProteinPoint]) {
        selectedPoints = points
    }
}

// MARK: - Plot Render View State

/// Controls plot rendering and refresh behavior
struct PlotRenderViewState {
    var plotId: UUID = UUID()
    var refreshTrigger: Int = 0
    var coordinateRefreshTrigger: Int = 0

    // MARK: - State Transitions

    /// Force a complete plot update by generating a new UUID
    mutating func forceUpdate() {
        plotId = UUID()
    }

    /// Increment the refresh trigger to regenerate the plot
    mutating func triggerRefresh() {
        refreshTrigger += 1
    }

    /// Increment the coordinate refresh trigger to recalculate coordinates
    mutating func triggerCoordinateRefresh() {
        coordinateRefreshTrigger += 1
    }

    /// Reset all triggers (useful for cleanup)
    mutating func reset() {
        plotId = UUID()
        refreshTrigger = 0
        coordinateRefreshTrigger = 0
    }
}

// MARK: - UI Modal View State

/// Manages modal presentation states (search, annotation editor)
struct UIModalViewState {
    var showingProteinSearch: Bool = false
    var showingAnnotationEditor: Bool = false
    var selectedAnnotationsForEdit: [AnnotationEditCandidate] = []

    // MARK: - Computed Properties

    /// Returns true if there are annotations selected for editing
    var hasSelectedAnnotations: Bool { !selectedAnnotationsForEdit.isEmpty }

    /// Returns true if any modal is currently shown
    var isAnyModalPresented: Bool {
        showingProteinSearch || showingAnnotationEditor
    }

    // MARK: - State Transitions

    /// Show the protein search modal
    mutating func showProteinSearch() {
        showingProteinSearch = true
    }

    /// Hide the protein search modal
    mutating func hideProteinSearch() {
        showingProteinSearch = false
    }

    /// Show the annotation editor modal with selected candidates
    mutating func showAnnotationEditor(with candidates: [AnnotationEditCandidate]) {
        selectedAnnotationsForEdit = candidates
        showingAnnotationEditor = true
    }

    /// Hide the annotation editor modal and clear selected annotations
    mutating func hideAnnotationEditor() {
        showingAnnotationEditor = false
        selectedAnnotationsForEdit = []
    }

    /// Dismiss all modals
    mutating func dismissAll() {
        hideProteinSearch()
        hideAnnotationEditor()
    }
}

// MARK: - Annotation Positioning View State

/// Manages annotation positioning workflow (interactive drag-to-position)
struct AnnotationPositioningViewState {
    var isInteractivePositioning: Bool = false
    var positioningCandidate: AnnotationEditCandidate? = nil
    var isPreviewingPosition: Bool = false
    var previewOffsetX: Double = 0.0
    var previewOffsetY: Double = 0.0
    var originalOffsetX: Double = 0.0
    var originalOffsetY: Double = 0.0

    // MARK: - Computed Properties

    /// Returns true if there's an active positioning operation
    var hasActivePositioning: Bool {
        positioningCandidate != nil && isInteractivePositioning
    }

    /// Returns true if the preview position differs from the original
    var isPositionChanged: Bool {
        previewOffsetX != originalOffsetX || previewOffsetY != originalOffsetY
    }

    /// Returns the current offset as a tuple for convenience
    var currentOffset: (x: Double, y: Double) {
        (previewOffsetX, previewOffsetY)
    }

    /// Returns the original offset as a tuple for convenience
    var originalOffset: (x: Double, y: Double) {
        (originalOffsetX, originalOffsetY)
    }

    // MARK: - State Transitions

    /// Start positioning an annotation with original offset values
    mutating func startPositioning(candidate: AnnotationEditCandidate, originalAx: Double, originalAy: Double) {
        positioningCandidate = candidate
        isInteractivePositioning = true
        isPreviewingPosition = false
        originalOffsetX = originalAx
        originalOffsetY = originalAy
        previewOffsetX = originalAx
        previewOffsetY = originalAy
    }

    /// Update the preview offset during drag
    mutating func updatePreviewOffset(x: Double, y: Double) {
        previewOffsetX = x
        previewOffsetY = y
    }

    /// Start preview mode (show accept/reject buttons)
    mutating func startPreview() {
        isPreviewingPosition = true
    }

    /// Exit preview mode
    mutating func exitPreview() {
        isPreviewingPosition = false
    }

    /// Accept the new position (caller should save the position to data)
    mutating func acceptPosition() {
        // Position accepted, reset state
        reset()
    }

    /// Reject the new position and revert to original
    mutating func rejectPosition() {
        previewOffsetX = originalOffsetX
        previewOffsetY = originalOffsetY
        reset()
    }

    /// Cancel positioning without changes
    mutating func cancel() {
        reset()
    }

    /// Reset all positioning state
    mutating func reset() {
        isInteractivePositioning = false
        positioningCandidate = nil
        isPreviewingPosition = false
        previewOffsetX = 0.0
        previewOffsetY = 0.0
        originalOffsetX = 0.0
        originalOffsetY = 0.0
    }
}

// MARK: - Drag Operation View State

/// Manages drag gesture state and performance throttling
struct DragOperationViewState {
    var isDragging: Bool = false
    var lastDragTime: Date = Date()
    var cachedArrowPosition: CGPoint? = nil
    var dragStartPosition: CGPoint? = nil
    var currentDragPosition: CGPoint? = nil
    var isShowingDragPreview: Bool = false

    /// Throttle interval for drag updates (~60fps)
    static let dragThrottleInterval: TimeInterval = 0.016

    // MARK: - Computed Properties

    /// Returns true if there's an active drag with a current position
    var isActiveDrag: Bool { isDragging && currentDragPosition != nil }

    /// Returns true if enough time has passed to allow another drag update
    var shouldThrottleUpdate: Bool {
        Date().timeIntervalSince(lastDragTime) < Self.dragThrottleInterval
    }

    /// Returns true if drag has started and has a valid start position
    var hasDragStarted: Bool { dragStartPosition != nil }

    /// Calculate the drag delta from start to current position
    var dragDelta: CGPoint? {
        guard let start = dragStartPosition, let current = currentDragPosition else {
            return nil
        }
        return CGPoint(x: current.x - start.x, y: current.y - start.y)
    }

    /// Calculate the drag distance from start to current position
    var dragDistance: Double? {
        guard let delta = dragDelta else { return nil }
        return sqrt(delta.x * delta.x + delta.y * delta.y)
    }

    // MARK: - State Transitions

    /// Start a drag operation at the specified position
    mutating func startDrag(at position: CGPoint, arrowPosition: CGPoint) {
        isDragging = true
        dragStartPosition = position
        currentDragPosition = position
        cachedArrowPosition = arrowPosition
        isShowingDragPreview = true
        lastDragTime = Date()
    }

    /// Update the drag position (returns false if throttled)
    @discardableResult
    mutating func updateDrag(to position: CGPoint) -> Bool {
        // Check throttling
        guard !shouldThrottleUpdate else { return false }

        currentDragPosition = position
        lastDragTime = Date()
        return true
    }

    /// Force update drag position (bypass throttling)
    mutating func forceUpdateDrag(to position: CGPoint) {
        currentDragPosition = position
        lastDragTime = Date()
    }

    /// Complete the drag operation - keeps preview visible for user to accept/reject
    mutating func completeDrag() {
        isDragging = false
        // Keep isShowingDragPreview = true to show final position
        // Keep dragStartPosition and currentDragPosition for preview line
        // Keep cachedArrowPosition for calculations
    }

    /// End the drag operation and hide preview
    mutating func endDrag() {
        isDragging = false
        isShowingDragPreview = false
        dragStartPosition = nil
        currentDragPosition = nil
        // Keep cachedArrowPosition briefly for final calculations
    }

    /// Cancel the drag operation
    mutating func cancelDrag() {
        isDragging = false
        isShowingDragPreview = false
        dragStartPosition = nil
        currentDragPosition = nil
        cachedArrowPosition = nil
    }

    /// Reset all drag state
    mutating func reset() {
        isDragging = false
        lastDragTime = Date()
        cachedArrowPosition = nil
        dragStartPosition = nil
        currentDragPosition = nil
        isShowingDragPreview = false
    }
}
