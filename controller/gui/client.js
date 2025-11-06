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

      const button = document.createElement('button')
      button.type = 'button'
      root.appendChild(button)

      let isPasswordShown = false
      function updatePasswordVisibility(b) {
        isPasswordShown = b
        if (isPasswordShown) {
          input.type = 'text'
          button.title = 'Hide password'
          button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-eye-off"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>'
        } else {
          input.type = 'password'
          button.title = 'Show password'
          button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-eye"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>'
        }
      }

      button.style = `
        border: none;
        background-color: transparent;
        color: #555555;
        position: absolute;
        top: 0;
        bottom: 0;
        left: 100%;
        cursor: pointer;
        display: inline-flex;
        justify-content: center;
        align-items: center;
      `
      button.onclick = function (event) {
        updatePasswordVisibility(!isPasswordShown)
      }

      // Set up initial state
      updatePasswordVisibility(false)
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
      passwordInput.style = 'display: none; margin-top: 1rem;'

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
