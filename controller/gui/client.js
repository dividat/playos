/* Password input web component with a SHOW/HIDE toggle button.
 */
customElements.define(
  'show-password',
  class extends HTMLInputElement {
    constructor() {
      super()

      const input = this

      const root = installParent(input, document.createElement('span'))
      root.style = 'position: relative'

      const button = document.createElement('input')
      root.appendChild(button)

      let isPasswordShown = false
      function updatePasswordVisibility(b) {
        isPasswordShown = b
        if (isPasswordShown) {
          button.value = 'HIDE'
          input.type = 'text'
        } else {
          button.value = 'SHOW'
          input.type = 'password'
        }
      }

      input.type = 'password'
      input.style = 'padding-right: 3.5rem' // Space for the button
      input.oninput = function (e) {
        if (e.target.value.length > 0) {
          button.style.visibility = 'visible'
        } else {
          button.style.visibility = 'hidden'
          updatePasswordVisibility(false)
        }
      }

      // If the input has a right margin, position the button accordingly
      const rightMargin = parseFloat(window.getComputedStyle(input).getPropertyValue('margin-right'))

      button.type = 'button'
      button.value = 'SHOW'
      button.style = `
        visibility: hidden;
        border: none;
        background-color: transparent;
        color: #555555;
        position: absolute;
        top: 50%;
        right: calc(${rightMargin}px + 0.5rem);
        font-size: 50%;
        transform: translateY(-50%);
        cursor: pointer;
      `
      button.onclick = function() {
        updatePasswordVisibility(!isPasswordShown)
      }
    }
  },
  { extends: 'input' }
)

/* Place given node under a new parent node.
 *
 * Useful to extend nodes that can not have childreen in web components, for
 * ex. inputs.
 */
function installParent(node, newParent) {
    node.parentNode.replaceChild(newParent, node)
    newParent.appendChild(node)
    return newParent
}
