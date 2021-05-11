/* Password input web component with a SHOW/HIDE toggle button
 */
customElements.define(
  'password-input',
  class extends HTMLElement {
    constructor() {
      super()

      const root = this
      const input = document.createElement('input')
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

      // If the input has a right margin, position the button accordingly
      const rightMargin = parseFloat(
        window.getComputedStyle(root).getPropertyValue('margin-right'))

      root.style = 'position: relative'
      root.appendChild(input)
      root.appendChild(button)

      input.type = 'password'
      input.style = 'padding-right: 3.5rem';
      input.oninput = function (e) {
        if (e.target.value.length > 0) {
          button.style.visibility = 'visible'
        } else {
          button.style.visibility = 'hidden'
          updatePasswordVisibility(false)
        }
      }

      // Move root attributes to the input
      for (const attr of root.attributes) {
        input.setAttribute(attr.nodeName, attr.nodeValue)
        root.removeAttribute(attr.nodeName)
      }

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
  }
)
