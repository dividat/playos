/* Password input web component with a SHOW/HIDE toggle button.
 */
customElements.define(
  'show-password',
  class extends HTMLInputElement {
    constructor() {
      super()

      const input = this

      const root = wrap(input, document.createElement('span'))
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
        font-size: 65%;
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

      const buttonParent = wrap(button, document.createElement('span'))
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
        buttonParent.appendChild(spinnerParent)
      })
    }
  },
  { extends: 'form' }
)

/* Internet status web component.
 *
 * Ask HTTP server for current internet status, then show status.
 */
customElements.define(
  'internet-status',
  class extends HTMLDivElement {
    constructor() {
      super()

      const div = this

      const xhr = new XMLHttpRequest()
      xhr.onload = function() {
        div.className = '' // Remove loader
        if (xhr.status >= 200 && xhr.status < 300) {
          div.innerText = 'Connected'
          div.style.color = 'green'
        } else {
          div.innerText = 'Not Connected'
          div.style.color = 'red'
        }
      }
      xhr.open( 'GET', '/internet/status')
      xhr.send()
    }
  },
  { extends: 'div' }
)

/* Keep previous password web component.
 *
 * Propose to keep the previously defined password instead of re-defining a new one.
 */
customElements.define(
  'keep-previous-password',
  class extends HTMLDivElement {
    constructor() {
      super()

      const passwordInput = this
      const root = wrap(passwordInput, document.createElement('div'))

      // Prepend checkbox to enable or disable keeping previous password
      const input = document.createElement('input')
      input.name = 'keep_password'
      input.type = 'checkbox'
      input.className = 'd-Checkbox'
      input.checked = true
      const label = document.createElement('label')
      label.className = 'd-CheckboxLabel'
      label.appendChild(input)
      label.appendChild(document.createTextNode('Keep previously defined password'))
      root.prepend(label)

      // Hide password input
      passwordInput.style = 'display: none'

      // Toggle password input display on click
      input.addEventListener('click', function() {
        passwordInput.style.display = passwordInput.style.display === 'block' ? 'none' : 'block'
      })
    }
  },
  { extends: 'div' }
)

/* Place given node under a new parent node.
 *
 * Useful to extend nodes that can not have children in web components, for
 * ex. inputs.
 */
function wrap(node, newParent) {
    node.parentNode.replaceChild(newParent, node)
    newParent.appendChild(node)
    return newParent
}
