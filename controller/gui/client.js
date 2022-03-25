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

/* Form web component preventing more than one submission.
 *
 * Disable submit input inside the form after the first submission.
 */
customElements.define(
  'disable-after-submit',
  class extends HTMLFormElement {
    constructor() {
      super()

      const form = this
      const button = form.querySelector('input[type=submit]')

      const buttonParent = installParent(button, document.createElement('span'))
      buttonParent.style = `
        position: relative;
        height: fit-content;
      `

      const spinnerParent = document.createElement('div')
      spinnerParent.style = `
        display: flex;
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
      `

      const spinner = document.createElement('span')
      spinner.className = 'd-Spinner'
      spinnerParent.appendChild(spinner)

      form.addEventListener('submit', function() {
        button.disabled = true
        button.style.color = 'transparent'
        button.className += ' d-Button--Disabled'
        buttonParent.appendChild(spinnerParent)
      })
    }
  },
  { extends: 'form' }
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
