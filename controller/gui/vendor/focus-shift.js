/**
 * @overview focus-shift, library for spatial navigation with arrow keys
 *
 * https://github.com/dividat/focus-shift
 *
 * @copyright Dividat AG, 2024
 * @license MIT
 */

function init() {
  document.addEventListener("keydown", handleKeyDown)
}

/**
 * Handle any keydown event and decide whether it should be used for navigation.
 *
 * @param {KeyboardEvent} event
 * @returns {void}
 */
function handleKeyDown(event) {
  const direction = KEY_TO_DIRECTION[event.key]

  // Ignore irrelevant inputs
  if (
    direction == null ||
    hasModifiers(event) ||
    isInputInteraction(direction, event)
  ) {
    return
  } else {
    const eventTarget = document.activeElement || document.body
    const shiftFocusEvent = new CustomEvent("focus-shift:initiate", {
      detail: { keyboardEvent: event },
      cancelable: true,
      bubbles: true
    })
    eventTarget.dispatchEvent(shiftFocusEvent)

    logging.group(`focus-shift: ${event.key}`)
    if (shiftFocusEvent.defaultPrevented) {
      logging.debug(
        "Handling canceled via 'focus-shift:initiate' event",
        shiftFocusEvent
      )
    } else {
      event.preventDefault()
      handleUserDirection(KEY_TO_DIRECTION[event.key])
    }
    logging.groupEnd()
  }
}

/**
 * Handle a user's request for focus shift.
 *
 * @param {Direction} direction
 * @returns {void}
 */
function handleUserDirection(direction) {
  const container = getBlockingElement()
  const activeElement = getActiveElement(container)

  if (activeElement == null) {
    focusInitial(direction, container)
    return
  }

  const candidates = getFocusCandidates(direction, activeElement, container)
  if (candidates.length > 0) {
    performMove(direction, activeElement.getBoundingClientRect(), candidates)
  }
}

/**
 * Apply the initial focus within the given container.
 *
 * Standard heuristics are used to determine which element should be the first to receive focus.
 *
 * 1. Look for elements with explicit tabindex attribute set, choose lowest index > 0
 * 2. If no tabindex was set, treat container as a 'linear' group
 *
 * @param {Direction} direction
 * @param {Element} container
 * @returns {void}
 */
function focusInitial(direction, container) {
  // 1. tabindex
  /** @type {Array<Element & { tabIndex: number; }>} */
  const tabindexed = Array.from(container.querySelectorAll("[tabindex]"))
    .filter(hasTabIndex)
    .filter((elem) => elem.tabIndex > 0)
  const markedElement = getMinimumBy(tabindexed, (elem) => elem.tabIndex)
  if (markedElement != null) {
    applyFocus(direction, makeVirtualOrigin(direction), markedElement)
    return
  }

  // 2. 'linear' group
  focusLinear(direction, makeVirtualOrigin(direction), container)
}

/**
 * Get all focusable elements within the container.
 *
 * Only the top-most elements are returned, any descendants of focusable elements are omitted.
 *
 * @param {Element} container
 * @returns {Element[]}
 */
function getFocusableElements(container) {
  const selector =
    '[data-focus-group], [tabindex], a[href], button, input, textarea, select, [contenteditable="true"], summary'

  // Find the focusable elements within the container
  const focusableElements = Array.from(
    container.querySelectorAll(selector)
  ).filter(isFocusable)
  // Reduce to the focusable elements highest up the tree
  const topMostElements = focusableElements.filter((elem) => {
    return (
      elem.parentElement != null &&
      (elem.parentElement.closest(selector) === container ||
        elem.parentElement.closest(selector) == null)
    )
  })

  return topMostElements
}

/**
 * Tests whether an element may be focused using the keyboard.
 *
 * An element is inert for the purposes of this library if one or more of the following apply:
 *
 * - it has negative tabindex,
 * - it has been marked with `data-focus-skip`,
 * - it is a descendant of an element marked with `data-focus-skip`,
 * - it is a descendant of a closed `details` element,
 * - it is `disabled`,
 * - it is `inert`.
 *
 * Otherwise it counts as focusable.
 *
 * Properties are tested for before access, as the function may receive non-HTML elements.
 *
 * @param {Element} element
 * @returns {boolean} - True if the element may be focused using the keyboard
 */
function isFocusable(element) {
  // Has negative tabindex attribute explicitly set
  if (parseInt(element.getAttribute("tabindex") || "", 10) <= -1) return false
  // Is inert
  if ("inert" in element && element.inert) return false
  // Is disabled
  if ("disabled" in element && element.disabled) return false
  // Is or descends from skipped element
  if (
    element.hasAttribute("data-focus-skip") ||
    element.closest("[data-focus-skip]") != null
  )
    return false
  // Descends from closed details element
  if (hasClosedDetailsAncestor(element)) return false

  return true
}

/**
 * Tests whether the element is contained within a closed `details` element.
 *
 * `summary` elements are excluded (return value `false`) if they are the summary of the top-most
 * closed `details` element.
 *
 * @param {Element} element
 * @returns {boolean} - True if the element is hidden because of descending from closed `details`
 */
function hasClosedDetailsAncestor(element) {
  if (element.parentElement == null) return false

  const parentElement = element.parentElement
  if (element.tagName === "SUMMARY") {
    return hasClosedDetailsAncestor(parentElement)
  } else {
    return parentElement.closest("details:not([open])") != null
  }
}

/**
 * Get all candidates for receiving focus when moving from the active element in the given direction.
 *
 * @param {Direction} direction
 * @param {Element} activeElement
 * @param {Element} container
 * @returns {Array<AnnotatedElement>} - All elements that lie in the direction of movement from the active element
 */
function getFocusCandidates(direction, activeElement, container) {
  const activeRect = activeElement.getBoundingClientRect()

  let nextParent = activeElement || container
  let candidateElements = []

  do {
    nextParent =
      (nextParent.parentElement &&
        nextParent.parentElement.closest("[data-focus-group]")) ||
      container

    const annotatedElements = getFocusableElements(nextParent).map((e) =>
      annotate(direction, activeRect, e)
    )

    candidateElements = annotatedElements.filter(({ rect }) => {
      switch (direction) {
        case "left":
          return Math.floor(rect.right) <= activeRect.left
        case "up":
          return Math.floor(rect.bottom) <= activeRect.top
        case "right":
          return Math.ceil(rect.left) >= activeRect.right
        case "down":
          return Math.ceil(rect.top) >= activeRect.bottom
      }
    })
  } while (candidateElements.length === 0 && nextParent !== container)

  return candidateElements
}

/**
 * Perform a move, guaranteeing that focus is going to change if `candidates` is non-empty.
 *
 * This function only selects the "best" from the list of candidates it is given.
 *
 * @param {Direction} direction
 * @param {DOMRect} originRect - The bounding box of the element that has focus at the time the move is initiated
 * @param {Array<AnnotatedElement>} candidates - The candidates from which to pick
 * @returns {void}
 */
function performMove(direction, originRect, candidates) {
  logging.debug("performMove", direction, originRect, candidates)

  const originPoint = makeOrigin(direction, originRect)

  const candidatesInDirectProjection = candidates.filter((candidate) =>
    isWithinProjection(direction, originRect, candidate.rect)
  )

  if (candidatesInDirectProjection.length > 0) {
    candidates = candidatesInDirectProjection
  }

  const bestCandidate = getMinimumBy(candidates, (candidate) =>
    euclidean(originPoint, candidate.point)
  )
  if (bestCandidate != null) {
    applyFocus(direction, originRect, bestCandidate.element)
  }
}

/**
 * Apply focus to an element, descending into it if it is a group.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} target
 * @returns {void}
 */
function applyFocus(direction, origin, target) {
  logging.debug("applyFocus", direction, target)

  const parentGroup = target.closest("[data-focus-group]")
  if (
    parentGroup != null &&
    parentGroup != target &&
    getGroupType(parentGroup) === "memorize"
  ) {
    const memorizingElement = /** @type {MemorizingElement} */ (parentGroup)
    memorizingElement.lastFocused = target
  }

  if (isGroup(target)) {
    dispatchGroupFocus(direction, origin, target)
  } else if ("focus" in target && typeof target.focus === "function") {
    const preventScroll = target.hasAttribute("data-focus-prevent-scroll")
    target.focus({ preventScroll: preventScroll })
  }
}

//
// Containers and focus traps
//

/**
 * Get the top-most blocking element on the page.
 *
 * This returns `document.body` if no other blocking elements are found.
 *
 * You can give a trap index to your elements, higher indices block lower
 * indices. Just `data-focus-trap` is equivalent to `data-focus-trap="0"`.
 *
 * NOTE Because the web APIs are lacking, we have to determine the order of
 * blocking elements heuristically. See open spec issues:
 *
 * - https://github.com/whatwg/html/issues/897
 * - https://github.com/whatwg/html/issues/8783
 * - https://github.com/whatwg/html/issues/9075
 *
 * To work around this limitation you can use explicit trap indices.
 *
 * @returns {Element}
 */
function getBlockingElement() {
  /** @type {Element[]} */
  let trapElements = []
  try {
    // Try top-layer pseudo class (2022+ browsers)
    trapElements = Array.from(document.querySelectorAll(":modal"))
  } catch (e) {
    logging.debug("Browser does not support ':modal' selector, ignoring.")
  }
  // If none, use fallback selector
  if (trapElements.length === 0) {
    trapElements = Array.from(
      document.querySelectorAll("dialog[open], [data-focus-trap]")
    )
  }

  // If no explicit trap elements were found, body is the top element
  return (
    getMinimumBy(trapElements, (elem) => -getTrapIndex(elem)) || document.body
  )
}

/**
 * Get the trap index for an element.
 *
 * - The numeric value of `data-focus-trap` if attribute is set
 * - `0` if the element has a boolean `data-focus-trap` attribute
 * - `0` if the element is an open dialog element
 * - `-Infinity` otherwise
 *
 * @param {Element} element
 * @returns {number}
 */
function getTrapIndex(element) {
  const attribute = element.getAttribute("data-focus-trap")
  if (typeof attribute === "string" && /\d+/.test(attribute)) {
    return parseInt(attribute, 10)
  } else if (element.hasAttribute("data-focus-trap")) {
    return 0
  } else if (
    element.tagName === "DIALOG" &&
    "open" in element &&
    element.open
  ) {
    return 0
  } else {
    return -Infinity
  }
}

/**
 * Get the currently active element, only within the given container.
 *
 * It might be that the document element has an active element, but the
 * container does not. In this case the function returns `null`.
 *
 * @param {Element} container
 * @returns {Element | null}
 */
function getActiveElement(container) {
  const activeElement = document.activeElement
  if (
    // The activeElement may be `null` or `document.body` if no element has focus
    // https://developer.mozilla.org/en-US/docs/Web/API/Document/activeElement#value
    activeElement == null ||
    activeElement === container ||
    // Ignore the activeElement if it is not within container
    !container.contains(activeElement)
  ) {
    return null
  }

  return activeElement
}

//
// Groups
//

/**
 * @typedef {'first' | 'last' | 'linear' | 'active' | 'memorize'} GroupType
 */

/**
 * Tests whether the element is annotated to be a group.
 *
 * @param {Element} element
 * @returns {boolean} - True if the element is a group
 */
function isGroup(element) {
  return getGroupType(element) != null
}

/**
 * Get the group type for an element, if any.
 *
 * @param {Element} element
 * @returns {GroupType | null} - The group type, or `null` if element is not a group
 */
function getGroupType(element) {
  if (!element.hasAttribute("data-focus-group")) {
    return null
  }

  const str = element.getAttribute("data-focus-group")
  switch (str) {
    case "first":
    case "last":
    case "linear":
    case "active":
    case "memorize":
      return str
    case "":
    case null:
      return "linear"
    default:
      console.warn(`Invalid focus group type: ${str}`)
      return null
  }
}

/**
 * Dispatches focus within a group.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 * @returns {void}
 */
function dispatchGroupFocus(direction, origin, group) {
  const strategy = getGroupType(group)
  switch (strategy) {
    case "first":
      focusFirstElement(direction, origin, group)
      break
    case "last":
      focusLastElement(direction, origin, group)
      break
    case "active":
      focusActiveElement(direction, origin, group)
      break
    case "linear":
      focusLinear(direction, origin, group)
      break
    case "memorize":
      focusMemorized(direction, origin, group)
      break
  }
}

/**
 * Focuses the first element in the given focus group.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 */
function focusFirstElement(direction, origin, group) {
  const focusables = getFocusableElements(group)
  if (focusables.length > 0) {
    applyFocus(direction, origin, focusables[0])
  }
}

/**
 * Focuses the last element in the given navigation group.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 */
function focusLastElement(direction, origin, group) {
  const focusables = getFocusableElements(group)
  if (focusables.length > 0) {
    applyFocus(direction, origin, focusables[focusables.length - 1])
  }
}

/**
 * Focuses the active element in the given navigation group.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 */
function focusActiveElement(direction, origin, group) {
  const activeElement = getFocusableElements(group).find((elem) =>
    elem.hasAttribute("data-focus-active")
  )
  if (activeElement) {
    applyFocus(direction, origin, activeElement)
  } else {
    focusFirstElement(direction, origin, group)
  }
}

/**
 * Moves focus linearly in the direction of "travel".
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 */
function focusLinear(direction, origin, group) {
  const originPoint = makeOrigin(opposite(direction), origin)
  const candidates = getFocusableElements(group).map((candidate) =>
    annotate(direction, origin, candidate)
  )
  const bestCandidate = getMinimumBy(candidates, (candidate) =>
    euclidean(originPoint, candidate.point)
  )
  if (bestCandidate != null) {
    applyFocus(direction, origin, bestCandidate.element)
  }
}

/**
 * Moves focus to the last focused element in the group.
 *
 * If a previously memorized element can not be found, behave as 'linear'.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {Element} group
 */
function focusMemorized(direction, origin, group) {
  if (isMemorizing(group) && group.contains(group.lastFocused)) {
    applyFocus(direction, origin, group.lastFocused)
  } else {
    focusLinear(direction, origin, group)
  }
}

/**
 * @typedef {Element & { lastFocused: Element; }} MemorizingElement - An HTML element with an additional memorized element property
 */

/**
 * Type guard for memorizing elements.
 *
 * @param {Element} elem
 * @returns {elem is MemorizingElement}
 * */
function isMemorizing(elem) {
  return "lastFocused" in elem && elem.lastFocused instanceof Element
}

//
// DOM and Events
//

/**
 * Tests whether the keyboard event announces any modifier keys.
 *
 * @param {KeyboardEvent} e
 * @returns {boolean}
 */
function hasModifiers(e) {
  return (
    e.shiftKey ||
    e.ctrlKey ||
    e.metaKey ||
    e.altKey ||
    e.getModifierState("CapsLock")
  )
}

/**
 * Tests whether the keyboard event is a form interaction that should not lead to focus shifts.
 *
 * Adapted from the Spatial Navigation Polyfill.
 *
 * Original Copyright (c) 2018-2019 LG Electronics Inc.
 * Source: https://github.com/WICG/spatial-navigation/polyfill
 * Licensed under the MIT license (MIT)
 *
 * @param {Direction} direction - The direction read from the keydown event
 * @param {KeyboardEvent} event - The original keydown event
 * @returns {boolean}
 */
function isInputInteraction(direction, event) {
  const eventTarget = document.activeElement

  if (
    eventTarget instanceof HTMLInputElement ||
    eventTarget instanceof HTMLTextAreaElement
  ) {
    const targetType = eventTarget.getAttribute("type")
    const isTextualInput = [
      "email",
      "password",
      "text",
      "search",
      "tel",
      "url",
      null
    ].includes(targetType)
    const isSpinnable =
      targetType != null &&
      ["date", "month", "number", "time", "week"].includes(targetType)

    if (isTextualInput || isSpinnable || eventTarget.nodeName === "TEXTAREA") {
      // If there is a selection, assume user action is an input interaction
      if (eventTarget.selectionStart !== eventTarget.selectionEnd) {
        return true
        // If there is only the cursor, check if it is natural to leave the element in given direction
      } else {
        const cursorPosition = eventTarget.selectionStart
        const isVerticalMove = direction === "up" || direction === "down"

        if (eventTarget.value.length === 0) {
          // If field is empty, leave in any direction
          return false
        } else if (cursorPosition == null) {
          // If cursor position was not given, we always exit unless we see a "spinning" input
          return isSpinnable && isVerticalMove
        } else if (cursorPosition === 0) {
          // Cursor at beginning
          return direction === "right" || (isSpinnable && isVerticalMove)
        } else if (cursorPosition === eventTarget.value.length) {
          // Cursor at end
          return direction === "left" || (isSpinnable && isVerticalMove)
        } else {
          // Cursor in middle
          return (
            direction === "left" ||
            direction === "right" ||
            (isSpinnable && isVerticalMove)
          )
        }
      }
    } else {
      return false
    }
  } else {
    return false
  }
}

/**
 * Type guard for tabindexed elements.
 *
 * @param {Element} elem
 * @returns {elem is Element & { tabIndex: number; }}
 * */
function hasTabIndex(elem) {
  return "tabIndex" in elem && typeof elem.tabIndex === "number"
}

//
// Geometry
//

/**
 * @typedef {'up' | 'right' | 'down' | 'left'} Direction
 */

/**
 * Returns the opposite direction.
 *
 * @param {Direction} direction
 * @returns {Direction}
 */
function opposite(direction) {
  switch (direction) {
    case "left":
      return "right"
    case "up":
      return "down"
    case "right":
      return "left"
    case "down":
      return "up"
  }
}

/**
 * Make the target point for a move between origin and target rect in given direction.
 *
 * @param {Direction} direction
 * @param {DOMRect} originRect
 * @param {DOMRect} targetRect
 * @returns {Point}
 */
function makeTarget(direction, originRect, targetRect) {
  switch (direction) {
    case "left":
      return {
        x: targetRect.right,
        y: closestTo(
          (originRect.top + originRect.bottom) / 2,
          targetRect.top,
          targetRect.bottom
        )
      }
    case "up":
      return {
        x: closestTo(
          (originRect.left + originRect.right) / 2,
          targetRect.left,
          targetRect.right
        ),
        y: targetRect.bottom
      }
    case "right":
      return {
        x: targetRect.left,
        y: closestTo(
          (originRect.top + originRect.bottom) / 2,
          targetRect.top,
          targetRect.bottom
        )
      }
    case "down":
      return {
        x: closestTo(
          (originRect.left + originRect.right) / 2,
          targetRect.left,
          targetRect.right
        ),
        y: targetRect.top
      }
  }
}

/**
 * Make the origin point for a move between origin and target rect in given direction.
 *
 * @param {Direction} direction
 * @param {DOMRect} originRect
 * @returns {Point}
 */
function makeOrigin(direction, originRect) {
  switch (direction) {
    case "left":
      return { x: originRect.left, y: originRect.top + originRect.height / 2 }
    case "up":
      return { x: originRect.left + originRect.width / 2, y: originRect.top }
    case "right":
      return { x: originRect.right, y: originRect.top + originRect.height / 2 }
    case "down":
      return { x: originRect.left + originRect.width / 2, y: originRect.bottom }
  }
}

/**
 * Make the virtual origin a movement would be expected to come from.
 *
 * This allows us to jump into the viewport from any of the four directions.
 *
 *               │
 *               ▼  ArrowDown
 * ArrowRight ──►┌────────────────────────┐◄─
 *               │                        │ ArrowLeft
 *               │                        │
 *               │                        │
 *               │                        │
 *               │                        │
 *               │                        │
 *               │                        │
 *               │                        │
 *               │                        │
 *               └────────────────────────┘
 *               ▲
 *               │ ArrowUp
 *
 * To keep it simple and based on own needs this assumes LTR text direction.
 * It could try to determine the user agent's preferred direction instead.
 *
 * @param {Direction} direction
 * @returns {DOMRect} - The region of the virtual origin
 */
function makeVirtualOrigin(direction) {
  const width = window.innerWidth
  const height = window.innerHeight
  switch (direction) {
    case "down":
    case "right":
      return DOMRect.fromRect({ x: 0, y: 0, width: 0, height: 0 })
    case "left":
      return DOMRect.fromRect({ x: width, y: 0, width: 0, height: 0 })
    case "up":
      return DOMRect.fromRect({ x: 0, y: height, width: 0, height: 0 })
  }
}

/**
 * Map the `key` property of a keyboard event to a `Direction`.
 *
 * @type {Object.<string, Direction>}
 */
const KEY_TO_DIRECTION = {
  ArrowUp: "up",
  ArrowRight: "right",
  ArrowDown: "down",
  ArrowLeft: "left"
}

/**
 * @typedef {Object} AnnotatedElement - An HTML element annotated with spatial information, specific to a move
 * @property {Element} element - The element
 * @property {DOMRect} rect - The bounding box for the element
 * @property {Point} point - The point defined as characteristic for the given move
 */

/**
 * Annotate an element with meta information for a given move.
 *
 * @param {Direction} direction
 * @param {DOMRect} originRect
 * @param {Element} element
 * @returns {AnnotatedElement}
 */
function annotate(direction, originRect, element) {
  const rect = element.getBoundingClientRect()
  return {
    element: element,
    rect: rect,
    point: makeTarget(direction, originRect, rect)
  }
}

/**
 * @typedef {{ x: number; y: number; }} Point
 */

/**
 * Computes the Euclidean distance between two points.
 *
 * @param {Point} a
 * @param {Point} b
 * @returns {number}
 */
function euclidean(a, b) {
  return Math.sqrt(Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2))
}

/**
 * Find the value closest to a given value that lies within the interval.
 *
 * @param {number} val - The value of interest
 * @param {number} intervalLower - The lower boundary of the interval
 * @param {number} intervalUpper - The upper boundary of the interval
 * @returns {number} - The value within the interval that is closest to the value of interest
 */
function closestTo(val, intervalLower, intervalUpper) {
  if (val >= intervalLower && val <= intervalUpper) {
    return val
  } else if (val > intervalUpper) {
    return intervalUpper
  } else {
    return intervalLower
  }
}

/**
 * Tests whether the candidate lies within the directed projection from the origin.
 *
 * @param {Direction} direction
 * @param {DOMRect} origin
 * @param {DOMRect} candidate
 * @returns {boolean} - True if the candidate lies within the projection
 */
function isWithinProjection(direction, origin, candidate) {
  switch (direction) {
    case "left":
    case "right":
      return hasOverlap(
        candidate.top,
        candidate.bottom,
        origin.top,
        origin.bottom
      )
    case "up":
    case "down":
      return hasOverlap(
        candidate.left,
        candidate.right,
        origin.left,
        origin.right
      )
    default:
      return false
  }
}

/**
 * Tests whether two intervals overlap.
 *
 * @param {number} start1 - The start of the first interval
 * @param {number} end1 - The end of the first interval
 * @param {number} start2 - The start of the second interval
 * @param {number} end2 - The end of the second interval
 * @returns {boolean}
 */
function hasOverlap(start1, end1, start2, end2) {
  return !(start1 > end2 || start2 > end1)
}

//
// Generic utilities
//

/**
 * Returns the element in `array` for which `toNumeric` is minimal.
 *
 * @template T
 * @param {Array<T>} array
 * @param {(item: T) => number} toNumber
 * @returns {T | null}
 */
function getMinimumBy(array, toNumber) {
  let minVal = Infinity
  let min = null
  let currentVal = Infinity

  for (let current of array) {
    currentVal = toNumber(current)

    if (currentVal < minVal) {
      minVal = currentVal
      min = current
    }
  }

  return min
}

const logging = /** @type {Console} */ (
  new Proxy(console, {
    get: /** @type {(target: any, level: any) => any} */ (
      function (target, level) {
        if ("FOCUS_SHIFT_DEBUG" in window && window.FOCUS_SHIFT_DEBUG) {
          if (level in target && typeof target[level] === "function") {
            return /** @type {(args: any[]) => void} */ (
              function (...args) {
                target[level].apply(target, args)
              }
            )
          } else if (level in target) {
            return target[level]
          }
        } else {
          return function () {}
        }
      }
    )
  })
)

init()
