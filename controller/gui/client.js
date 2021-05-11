/* Password input web component with a SHOW/HIDE toggle button
 */
customElements.define(
  'show-password',
  class extends HTMLInputElement {
    constructor() {
      super()

      const parentNode = this.parentNode
      const input = this
      const root = document.createElement('span')
      const button = document.createElement('input')

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

      // Move the input (current root) under the new artificial root, and also
      // append the button
      parentNode.replaceChild(root, input)
      root.appendChild(input)
      root.appendChild(button)
      root.style = 'position: relative'

      input.type = 'password'
      input.style = 'padding-right: 3.5rem'; // Space for the button
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
